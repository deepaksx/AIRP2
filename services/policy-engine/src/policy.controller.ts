import { Controller, Get, Post, Body, Param, Query, Logger } from '@nestjs/common';
import { PolicyService } from './policy.service';

@Controller('policy')
export class PolicyController {
  private readonly logger = new Logger(PolicyController.name);

  constructor(private readonly policyService: PolicyService) {}

  @Post('evaluate')
  async evaluatePolicy(@Body() policyData: any) {
    this.logger.log(`Evaluating policy: ${policyData.policy_name}`);
    return this.policyService.evaluatePolicy(policyData);
  }

  @Get('workflows')
  async getWorkflows(@Query('tenant_id') tenantId: string, @Query('status') status?: string) {
    this.logger.log(`Fetching workflows for tenant: ${tenantId}`);
    return this.policyService.getWorkflows(tenantId, status);
  }

  @Post('workflows/:id/approve')
  async approveWorkflow(@Param('id') id: string, @Body() approvalData: any) {
    this.logger.log(`Approving workflow: ${id}`);
    return this.policyService.approveWorkflow(id, approvalData);
  }

  @Post('workflows/:id/reject')
  async rejectWorkflow(@Param('id') id: string, @Body() rejectionData: any) {
    this.logger.log(`Rejecting workflow: ${id}`);
    return this.policyService.rejectWorkflow(id, rejectionData);
  }

  @Get('compliance-check')
  async checkCompliance(@Query() params: any) {
    this.logger.log(`Checking compliance for transaction`);
    return this.policyService.checkCompliance(params);
  }
}
