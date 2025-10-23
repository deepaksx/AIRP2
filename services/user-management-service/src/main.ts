import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe, Logger } from '@nestjs/common';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule);

  // Enable validation
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true,
  }));

  // Enable CORS
  app.enableCors({
    origin: '*', // Configure appropriately for production
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    credentials: true,
  });

  const port = process.env.PORT || 3009;
  await app.listen(port);

  logger.log(`🚀 User Management Service running on port ${port}`);
  logger.log(`📊 Health check: http://localhost:${port}/health`);
  logger.log(`👥 Users API: http://localhost:${port}/users`);
  logger.log(`🔐 Context auto-updater enabled (runs every 5 minutes)`);
}

bootstrap();
