import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const logger = new Logger('TreasuryService');

  const app = await NestFactory.create(AppModule);

  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true,
  }));

  app.enableCors();

  const port = process.env.PORT || 3005;
  await app.listen(port);

  logger.log('='.repeat(60));
  logger.log('AIRP v2.0 - Treasury Service');
  logger.log('Cash Management, Bank Reconciliation & Forecasting');
  logger.log('='.repeat(60));
  logger.log(`API Server: http://localhost:${port}`);
  logger.log('='.repeat(60));
}

bootstrap();
