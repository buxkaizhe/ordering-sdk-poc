import { configDotenv } from 'dotenv';
import { z } from 'zod';

configDotenv();

const envSchema = z
  .object({
    ABLY_API_KEY: z.string(),
  })
  .passthrough();

type Env = z.infer<typeof envSchema> & NodeJS.ProcessEnv;

export const env = envSchema.parse(process.env) as Env;
