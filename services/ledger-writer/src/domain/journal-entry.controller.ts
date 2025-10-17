import { Controller, Post, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { JournalEntryService, CreateJournalEntryDto } from './journal-entry.service';

@ApiTags('journal-entries')
@Controller('journal-entries')
export class JournalEntryController {
  constructor(private readonly journalEntryService: JournalEntryService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a new journal entry' })
  @ApiResponse({ status: 201, description: 'Journal entry created and posted' })
  @ApiResponse({ status: 400, description: 'Invalid journal entry (unbalanced or missing data)' })
  async createJournalEntry(@Body() dto: CreateJournalEntryDto) {
    return this.journalEntryService.createJournalEntry(dto);
  }

  @Post('reverse')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Reverse a journal entry' })
  @ApiResponse({ status: 201, description: 'Journal entry reversed' })
  @ApiResponse({ status: 404, description: 'Original entry not found' })
  async reverseJournalEntry(
    @Body()
    dto: {
      entryId: string;
      tenantId: string;
      userId: string;
      reason: string;
    },
  ) {
    return this.journalEntryService.reverseJournalEntry(
      dto.entryId,
      dto.tenantId,
      dto.userId,
      dto.reason,
    );
  }
}
