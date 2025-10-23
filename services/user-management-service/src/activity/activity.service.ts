import { Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

@Injectable()
export class ActivityService {
  private readonly logger = new Logger(ActivityService.name);

  constructor(
    @InjectDataSource()
    private dataSource: DataSource,
  ) {}

  async logActivity(activity: {
    tenant_id: string;
    user_id: string;
    activity_type: string;
    resource_type?: string;
    resource_id?: string;
    action_description: string;
    ip_address?: string;
    user_agent?: string;
    request_method?: string;
    request_path?: string;
    response_status?: number;
    duration_ms?: number;
    activity_data?: any;
    session_id?: string;
  }): Promise<void> {
    try {
      await this.dataSource.query(`
        INSERT INTO user_activity_log (
          tenant_id, user_id, activity_type, resource_type, resource_id,
          action_description, ip_address, user_agent, request_method,
          request_path, response_status, duration_ms, activity_data, session_id, timestamp
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, NOW())
      `, [
        activity.tenant_id,
        activity.user_id,
        activity.activity_type,
        activity.resource_type || null,
        activity.resource_id || null,
        activity.action_description,
        activity.ip_address || null,
        activity.user_agent || null,
        activity.request_method || null,
        activity.request_path || null,
        activity.response_status || null,
        activity.duration_ms || null,
        activity.activity_data ? JSON.stringify(activity.activity_data) : null,
        activity.session_id || null,
      ]);
    } catch (error) {
      this.logger.error('Failed to log activity:', error);
      // Don't throw - activity logging is non-critical
    }
  }

  async getActivitiesForUser(userId: string, limit: number = 100): Promise<any[]> {
    return this.dataSource.query(`
      SELECT
        activity_id,
        activity_type,
        resource_type,
        resource_id,
        action_description,
        ip_address,
        timestamp,
        duration_ms
      FROM user_activity_log
      WHERE user_id = $1
      ORDER BY timestamp DESC
      LIMIT $2
    `, [userId, limit]);
  }

  async getActivitiesByTenant(tenantId: string, limit: number = 100): Promise<any[]> {
    return this.dataSource.query(`
      SELECT
        al.activity_id,
        u.username,
        u.full_name,
        al.activity_type,
        al.resource_type,
        al.resource_id,
        al.action_description,
        al.timestamp
      FROM user_activity_log al
      JOIN users u ON al.user_id = u.user_id
      WHERE al.tenant_id = $1
      ORDER BY al.timestamp DESC
      LIMIT $2
    `, [tenantId, limit]);
  }
}
