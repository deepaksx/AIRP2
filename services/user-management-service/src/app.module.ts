import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule';
import { User } from './users/user.entity';
import { Role } from './roles/role.entity';
import { Permission } from './permissions/permission.entity';
import { UsersService } from './users/users.service';
import { UsersController } from './users/users.controller';
import { ActivityService } from './activity/activity.service';
import { ContextUpdaterService } from './workers/context-updater.service';
import { HealthController } from './health/health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    ScheduleModule.forRoot(),
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT, 10) || 5432,
      username: process.env.DB_USER || 'airp_admin',
      password: process.env.DB_PASSWORD || 'airp_secure_2024',
      database: process.env.DB_NAME || 'airp_master',
      entities: [User, Role, Permission],
      synchronize: false, // Never use true in production
      logging: process.env.NODE_ENV === 'development',
    }),
    TypeOrmModule.forFeature([User, Role, Permission]),
  ],
  controllers: [UsersController, HealthController],
  providers: [UsersService, ActivityService, ContextUpdaterService],
})
export class AppModule {}
