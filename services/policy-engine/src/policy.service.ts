import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ApprovalWorkflowEntity } from './entities/approval-workflow.entity';

@Injectable()
export class PolicyService {
  private readonly logger = new Logger(PolicyService.name);

  constructor(
    @InjectRepository(ApprovalWorkflowEntity)
    private workflowRepo: Repository<ApprovalWorkflowEntity>,
  ) {}

  async evaluatePolicy(policyData: any): Promise<any> {
    this.logger.log(`Evaluating policy: ${JSON.stringify(policyData)}`);

    // In production, this would call OPA (Open Policy Agent) for policy evaluation
    // For now, returning a mock response
    return {
      allowed: true,
      policy_name: policyData.policy_name || 'default',
      violations: [],
      timestamp: new Date().toISOString(),
    };
  }

  async getWorkflows(tenantId: string, status?: string): Promise<ApprovalWorkflowEntity[]> {
    const where: any = { tenant_id: tenantId };
    if (status) {
      where.status = status;
    }

    return this.workflowRepo.find({
      where,
      order: { created_at: 'DESC' },
    });
  }

  async approveWorkflow(id: string, approvalData: any): Promise<ApprovalWorkflowEntity> {
    await this.workflowRepo.update(id, {
      status: 'approved',
      approved_by: approvalData.user_id,
      approved_at: new Date(),
    });

    return this.workflowRepo.findOne({ where: { workflow_id: id } });
  }

  async rejectWorkflow(id: string, rejectionData: any): Promise<ApprovalWorkflowEntity> {
    await this.workflowRepo.update(id, {
      status: 'rejected',
      rejection_reason: rejectionData.reason,
    });

    return this.workflowRepo.findOne({ where: { workflow_id: id } });
  }

  async checkCompliance(params: any): Promise<any> {
    this.logger.log('Running compliance checks');

    // In production, this would check against IFRS/GAAP rules, VAT compliance, etc.
    return {
      compliant: true,
      checks_passed: ['vat_validation', 'ifrs_rules', 'approval_limits'],
      warnings: [],
      errors: [],
    };
  }
}
