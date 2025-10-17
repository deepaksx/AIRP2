import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const logger = new Logger('ARService');

  const app = await NestFactory.create(AppModule);

  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true,
  }));

  app.enableCors();

  const port = process.env.PORT || 3004;
  await app.listen(port);

  logger.log('='.repeat(60));
  logger.log('AIRP v2.0 - Accounts Receivable Service');
  logger.log('Customer Management & Revenue Recognition');
  logger.log('='.repeat(60));
  logger.log(`API Server: http://localhost:${port}`);
  logger.log(`Swagger Docs: http://localhost:${port}/api`);
  logger.log('='.repeat(60));
}

bootstrap();
