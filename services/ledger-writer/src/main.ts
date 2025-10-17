import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ['log', 'error', 'warn', 'debug', 'verbose'],
  });

  // Enable validation
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  // Enable CORS
  app.enableCors({
    origin: process.env.CORS_ORIGIN || '*',
    credentials: true,
  });

  // Swagger documentation
  const config = new DocumentBuilder()
    .setTitle('AIRP v2.0 - Ledger Writer API')
    .setDescription('Event-sourced immutable ledger write API')
    .setVersion('2.0.0')
    .addTag('events', 'Event Store Operations')
    .addTag('journal-entries', 'Journal Entry Management')
    .addTag('health', 'Health Checks')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  // Get port from environment
  const port = process.env.PORT || 3001;

  await app.listen(port, '0.0.0.0');

  console.log(`
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   AIRP v2.0 - Ledger Writer Service                      ║
║   AI-Native Financial ERP                                ║
║                                                           ║
║   Status: Running                                         ║
║   Port: ${port}                                              ║
║   Environment: ${process.env.NODE_ENV || 'development'}                                ║
║   Swagger Docs: http://localhost:${port}/api/docs             ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
  `);
}

bootstrap().catch((error) => {
  console.error('Failed to start Ledger Writer service:', error);
  process.exit(1);
});
