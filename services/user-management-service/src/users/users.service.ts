import { Injectable, Logger, NotFoundException, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { User } from './user.entity';
import * as bcrypt from 'bcrypt';
import axios from 'axios';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);
  private readonly AI_CONTEXT_SERVICE_URL = process.env.AI_CONTEXT_SERVICE_URL || 'http://localhost:8007';

  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
    private dataSource: DataSource,
  ) {}

  async findAll(tenantId: string): Promise<User[]> {
    return this.usersRepository.find({
      where: { tenant_id: tenantId },
      select: [
        'user_id', 'username', 'email', 'full_name', 'employee_id',
        'department', 'job_title', 'phone', 'status', 'last_login_at',
        'ai_context_summary', 'ai_context_keywords', 'created_at', 'updated_at'
      ],
      order: { created_at: 'DESC' }
    });
  }

  async findOne(userId: string): Promise<User> {
    const user = await this.usersRepository.findOne({
      where: { user_id: userId },
      select: [
        'user_id', 'tenant_id', 'username', 'email', 'full_name', 'employee_id',
        'department', 'job_title', 'phone', 'status', 'last_login_at',
        'failed_login_attempts', 'locked_until', 'preferences',
        'ai_context_summary', 'ai_context_keywords', 'ai_context_entities',
        'ai_context_relationships', 'ai_context_generated_at',
        'ai_context_model_version', 'created_at', 'updated_at'
      ]
    });

    if (!user) {
      throw new NotFoundException(`User ${userId} not found`);
    }

    return user;
  }

  async create(createUserDto: any): Promise<User> {
    // Check if username or email already exists
    const existing = await this.usersRepository.findOne({
      where: [
        { username: createUserDto.username },
        { email: createUserDto.email }
      ]
    });

    if (existing) {
      throw new ConflictException('Username or email already exists');
    }

    // Hash password
    const passwordHash = await bcrypt.hash(createUserDto.password, 10);

    const user = this.usersRepository.create({
      ...createUserDto,
      password_hash: passwordHash,
      password_changed_at: new Date(),
      status: createUserDto.status || 'active',
    });

    const saved = await this.usersRepository.save(user);

    // Trigger async context generation
    this.generateContextForUser(saved.user_id).catch(err =>
      this.logger.error(`Failed to generate context for user ${saved.user_id}:`, err)
    );

    // Remove password hash before returning
    delete saved.password_hash;
    return saved;
  }

  async update(userId: string, updateUserDto: any): Promise<User> {
    const user = await this.findOne(userId);

    // If password is being changed, hash it
    if (updateUserDto.password) {
      updateUserDto.password_hash = await bcrypt.hash(updateUserDto.password, 10);
      updateUserDto.password_changed_at = new Date();
      delete updateUserDto.password;
    }

    Object.assign(user, updateUserDto);
    user.updated_at = new Date();

    const saved = await this.usersRepository.save(user);

    // Trigger async context generation
    this.generateContextForUser(saved.user_id).catch(err =>
      this.logger.error(`Failed to generate context for user ${saved.user_id}:`, err)
    );

    delete saved.password_hash;
    return saved;
  }

  async delete(userId: string): Promise<void> {
    const user = await this.findOne(userId);

    // Soft delete by setting status to inactive
    user.status = 'inactive';
    user.updated_at = new Date();
    await this.usersRepository.save(user);

    this.logger.log(`User ${userId} soft-deleted (status=inactive)`);
  }

  async updateLoginInfo(userId: string, ipAddress: string): Promise<void> {
    await this.usersRepository.update(userId, {
      last_login_at: new Date(),
      last_login_ip: ipAddress,
      failed_login_attempts: 0,
      locked_until: null,
    });
  }

  async incrementFailedLogin(userId: string): Promise<void> {
    const user = await this.findOne(userId);
    user.failed_login_attempts = (user.failed_login_attempts || 0) + 1;

    // Lock account after 5 failed attempts for 30 minutes
    if (user.failed_login_attempts >= 5) {
      user.locked_until = new Date(Date.now() + 30 * 60 * 1000);
      user.status = 'locked';
    }

    await this.usersRepository.save(user);
  }

  async getUserPermissions(userId: string): Promise<any[]> {
    const query = `
      SELECT DISTINCT
        p.permission_id,
        p.permission_code,
        p.permission_name,
        p.resource,
        p.action
      FROM users u
      JOIN user_roles ur ON u.user_id = ur.user_id AND ur.is_active = true
      JOIN roles r ON ur.role_id = r.role_id AND r.is_active = true
      JOIN role_permissions rp ON r.role_id = rp.role_id
      JOIN permissions p ON rp.permission_id = p.permission_id
      WHERE u.user_id = $1
      ORDER BY p.resource, p.action
    `;

    return this.dataSource.query(query, [userId]);
  }

  async getUserActivity(userId: string, limit: number = 50): Promise<any[]> {
    const query = `
      SELECT
        activity_id,
        activity_type,
        resource_type,
        resource_id,
        action_description,
        timestamp,
        ip_address,
        duration_ms
      FROM user_activity_log
      WHERE user_id = $1
      ORDER BY timestamp DESC
      LIMIT $2
    `;

    return this.dataSource.query(query, [userId, limit]);
  }

  async generateContextForUser(userId: string): Promise<void> {
    this.logger.log(`Generating AI context for user ${userId}...`);

    try {
      // Get user data
      const user = await this.findOne(userId);

      // Get user activity stats
      const activityStats = await this.dataSource.query(`
        SELECT
          COUNT(*) as total_activities,
          COUNT(DISTINCT activity_type) as unique_activity_types,
          json_agg(DISTINCT activity_type) as activity_types,
          MAX(timestamp) as last_activity_at
        FROM user_activity_log
        WHERE user_id = $1 AND timestamp >= NOW() - INTERVAL '90 days'
      `, [userId]);

      // Get most accessed resources
      const resourceStats = await this.dataSource.query(`
        SELECT
          resource_type,
          COUNT(*) as access_count,
          json_agg(DISTINCT resource_id) as resource_ids
        FROM user_activity_log
        WHERE user_id = $1 AND resource_id IS NOT NULL
          AND timestamp >= NOW() - INTERVAL '90 days'
        GROUP BY resource_type
        ORDER BY access_count DESC
        LIMIT 10
      `, [userId]);

      // Build context payload
      const contextPayload = {
        entity_type: 'user',
        entity_id: userId,
        entity_data: {
          username: user.username,
          email: user.email,
          full_name: user.full_name,
          department: user.department,
          job_title: user.job_title,
          status: user.status,
          last_login: user.last_login_at,
          activity_stats: activityStats[0],
          resource_access: resourceStats,
        },
        tenant_id: user.tenant_id,
      };

      // Call AI Context Generator service
      const response = await axios.post(
        `${this.AI_CONTEXT_SERVICE_URL}/generate-context`,
        contextPayload,
        { timeout: 30000 }
      );

      // Update user with generated context
      await this.usersRepository.update(userId, {
        ai_context_summary: response.data.summary,
        ai_context_keywords: response.data.keywords,
        ai_context_entities: response.data.entities,
        ai_context_relationships: response.data.relationships,
        ai_context_generated_at: new Date(),
        ai_context_model_version: response.data.model_version || 'claude-3.5-sonnet',
      });

      this.logger.log(`Successfully generated context for user ${userId}`);
    } catch (error) {
      this.logger.error(`Context generation failed for user ${userId}:`, error.message);
      // Don't throw - context generation is non-critical
    }
  }

  async searchUsers(tenantId: string, query: string): Promise<User[]> {
    return this.usersRepository
      .createQueryBuilder('user')
      .where('user.tenant_id = :tenantId', { tenantId })
      .andWhere(
        '(user.username ILIKE :query OR user.email ILIKE :query OR user.full_name ILIKE :query OR :query = ANY(user.ai_context_keywords))',
        { query: `%${query}%` }
      )
      .select([
        'user.user_id', 'user.username', 'user.email', 'user.full_name',
        'user.department', 'user.job_title', 'user.status', 'user.ai_context_summary'
      ])
      .limit(20)
      .getMany();
  }

  async getContextHistory(userId: string): Promise<any[]> {
    this.logger.log(`Fetching context history for user ${userId}`);

    const result = await this.dataSource.query(`
      SELECT * FROM get_context_history('user', $1)
    `, [userId]);

    return result.map(row => ({
      snapshotIndex: row.snapshot_index,
      summary: row.summary,
      keywords: row.keywords,
      entities: row.entities,
      relationships: row.relationships,
      generatedAt: row.generated_at,
      modelVersion: row.model_version,
    }));
  }

  async getContextEvolution(userId: string): Promise<any> {
    this.logger.log(`Fetching context evolution for user ${userId}`);

    const user = await this.usersRepository.findOne({
      where: { user_id: userId },
      select: [
        'user_id', 'username', 'full_name',
        'ai_context_summary', 'ai_context_keywords',
        'ai_context_generated_at', 'ai_context_model_version'
      ]
    });

    if (!user) {
      throw new NotFoundException(`User ${userId} not found`);
    }

    const history = await this.getContextHistory(userId);

    return {
      user_id: user.user_id,
      username: user.username,
      full_name: user.full_name,
      current_context: {
        summary: user.ai_context_summary,
        keywords: user.ai_context_keywords,
        keyword_count: user.ai_context_keywords?.length || 0,
        generated_at: user.ai_context_generated_at,
        model_version: user.ai_context_model_version,
      },
      history_count: history.length,
      history: history,
      keyword_evolution: this.analyzeKeywordEvolution(history, user.ai_context_keywords),
    };
  }

  private analyzeKeywordEvolution(history: any[], currentKeywords: string[]): any {
    if (!history || history.length === 0) {
      return {
        total_unique_keywords: currentKeywords?.length || 0,
        new_keywords: [],
        persistent_keywords: currentKeywords || [],
        removed_keywords: [],
      };
    }

    const oldestKeywords = new Set(history[history.length - 1].keywords || []);
    const currentSet = new Set(currentKeywords || []);

    const newKeywords = Array.from(currentSet).filter(k => !oldestKeywords.has(k));
    const removedKeywords = Array.from(oldestKeywords).filter(k => !currentSet.has(k));
    const persistentKeywords = Array.from(currentSet).filter(k => oldestKeywords.has(k));

    return {
      total_unique_keywords: currentSet.size,
      new_keywords: newKeywords,
      persistent_keywords: persistentKeywords,
      removed_keywords: removedKeywords,
      growth_rate: oldestKeywords.size > 0
        ? ((currentSet.size - oldestKeywords.size) / oldestKeywords.size * 100).toFixed(1) + '%'
        : 'N/A',
    };
  }
}
