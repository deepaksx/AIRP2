import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const logger = new Logger('InventoryService');

  const app = await NestFactory.create(AppModule);

  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true,
  }));

  app.enableCors();

  const port = process.env.PORT || 3009;
  await app.listen(port);

  logger.log('='.repeat(60));
  logger.log('AIRP v2.14 - Inventory, Procurement & Sales Service');
  logger.log('Complete Supply Chain Management with COPA Integration');
  logger.log('='.repeat(60));
  logger.log(`API Server: http://localhost:${port}`);
  logger.log(`Swagger Docs: http://localhost:${port}/api`);
  logger.log('='.repeat(60));
  logger.log('Modules: Inventory | Procurement | Sales | COPA');
  logger.log('='.repeat(60));
}

bootstrap();
