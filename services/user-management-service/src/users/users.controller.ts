import { Controller, Get, Post, Put, Delete, Body, Param, Query, Logger } from '@nestjs/common';
import { UsersService } from './users.service';
import { ActivityService } from '../activity/activity.service';

@Controller('users')
export class UsersController {
  private readonly logger = new Logger(UsersController.name);

  constructor(
    private readonly usersService: UsersService,
    private readonly activityService: ActivityService,
  ) {}

  @Get()
  async findAll(@Query('tenant_id') tenantId: string) {
    this.logger.log(`Fetching all users for tenant: ${tenantId}`);
    return this.usersService.findAll(tenantId);
  }

  @Get('search')
  async search(@Query('tenant_id') tenantId: string, @Query('q') query: string) {
    this.logger.log(`Searching users: ${query}`);
    return this.usersService.searchUsers(tenantId, query);
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.usersService.findOne(id);
  }

  @Get(':id/permissions')
  async getPermissions(@Param('id') id: string) {
    return this.usersService.getUserPermissions(id);
  }

  @Get(':id/activity')
  async getActivity(@Param('id') id: string, @Query('limit') limit?: number) {
    return this.usersService.getUserActivity(id, limit ? parseInt(limit as any) : 50);
  }

  @Post()
  async create(@Body() createUserDto: any) {
    this.logger.log(`Creating user: ${createUserDto.username}`);
    const user = await this.usersService.create(createUserDto);

    await this.activityService.logActivity({
      tenant_id: user.tenant_id,
      user_id: createUserDto.created_by,
      activity_type: 'create',
      resource_type: 'user',
      resource_id: user.user_id,
      action_description: `Created user ${user.username}`,
    });

    return user;
  }

  @Put(':id')
  async update(@Param('id') id: string, @Body() updateUserDto: any) {
    this.logger.log(`Updating user: ${id}`);
    const user = await this.usersService.update(id, updateUserDto);

    await this.activityService.logActivity({
      tenant_id: user.tenant_id,
      user_id: updateUserDto.updated_by,
      activity_type: 'update',
      resource_type: 'user',
      resource_id: user.user_id,
      action_description: `Updated user ${user.username}`,
    });

    return user;
  }

  @Delete(':id')
  async delete(@Param('id') id: string, @Query('deleted_by') deletedBy: string) {
    this.logger.log(`Deleting user: ${id}`);
    const user = await this.usersService.findOne(id);
    await this.usersService.delete(id);

    await this.activityService.logActivity({
      tenant_id: user.tenant_id,
      user_id: deletedBy,
      activity_type: 'delete',
      resource_type: 'user',
      resource_id: id,
      action_description: `Deleted user ${user.username}`,
    });

    return { message: 'User deleted successfully' };
  }

  @Post(':id/regenerate-context')
  async regenerateContext(@Param('id') id: string) {
    this.logger.log(`Regenerating AI context for user: ${id}`);
    await this.usersService.generateContextForUser(id);
    return { message: 'Context regeneration started' };
  }

  @Get(':id/context-history')
  async getContextHistory(@Param('id') id: string) {
    this.logger.log(`Fetching context history for user: ${id}`);
    return this.usersService.getContextHistory(id);
  }

  @Get(':id/context-evolution')
  async getContextEvolution(@Param('id') id: string) {
    this.logger.log(`Fetching context evolution for user: ${id}`);
    return this.usersService.getContextEvolution(id);
  }
}
