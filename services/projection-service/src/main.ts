import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { MicroserviceOptions, Transport } from '@nestjs/microservices';
import { Logger } from '@nestjs/common';

async function bootstrap() {
  const logger = new Logger('ProjectionService');

  // Create HTTP app for health checks
  const app = await NestFactory.create(AppModule);

  // Add Kafka microservice
  app.connectMicroservice<MicroserviceOptions>({
    transport: Transport.KAFKA,
    options: {
      client: {
        clientId: 'projection-service',
        brokers: [(process.env.KAFKA_BROKERS || 'localhost:19092')],
      },
      consumer: {
        groupId: 'projection-service-group',
        allowAutoTopicCreation: false,
      },
    },
  });

  await app.startAllMicroservices();

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
