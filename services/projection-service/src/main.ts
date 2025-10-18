import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { Logger } from '@nestjs/common';

async function bootstrap() {
  const logger = new Logger('ProjectionService');

  // Create HTTP app (Kafka consumer is now initialized via EventConsumerService)
  const app = await NestFactory.create(AppModule);

  const port = process.env.PORT || 3002;
  await app.listen(port);

  logger.log('='.repeat(60));
  logger.log('AIRP v2.0 - Projection Service');
  logger.log('Event Consumer for Read Model Projections');
  logger.log('='.repeat(60));
  logger.log(`HTTP Server: http://localhost:${port}`);
  logger.log(`Kafka Brokers: ${process.env.KAFKA_BROKERS}`);
  logger.log('='.repeat(60));
}

bootstrap();
