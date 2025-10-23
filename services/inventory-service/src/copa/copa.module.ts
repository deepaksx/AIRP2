import { Module } from '@nestjs/common';
import { CopaController } from './copa.controller';
import { CopaService } from './copa.service';

@Module({
  controllers: [CopaController],
  providers: [CopaService],
  exports: [CopaService],
})
export class CopaModule {}
