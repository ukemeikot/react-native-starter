import { ApiError } from '@/shared/api/types';

import type { AuthResponse, AuthTokens, LoginRequest, RegisterRequest } from './auth.types';

const DUMMY_USER = {
  id: 'demo-user',
  email: 'demo@example.com',
  firstName: 'Demo',
  lastName: 'User',
};

const DUMMY_ACCESS = 'dummy.access.token';
const DUMMY_REFRESH = 'dummy.refresh.token';
const DUMMY_ACCESS_ROTATED = 'dummy.access.token.rotated';

function delay(ms: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}

async function login(data: LoginRequest): Promise<AuthResponse> {
  await delay(800);
  if (data.email === 'demo@example.com' && data.password === 'Password1') {
    return {
      user: DUMMY_USER,
      tokens: { accessToken: DUMMY_ACCESS, refreshToken: DUMMY_REFRESH },
    };
  }
  throw new ApiError('Invalid credentials', 401);
}

async function register(data: RegisterRequest): Promise<AuthResponse> {
  await delay(1000);
  if (!data.email || !data.password) {
    throw new ApiError('Email and password are required', 400);
  }
  return {
    user: {
      id: `user-${Date.now()}`,
      email: data.email,
      firstName: data.firstName,
      lastName: data.lastName,
    },
    tokens: { accessToken: DUMMY_ACCESS, refreshToken: DUMMY_REFRESH },
  };
}

async function refreshTokens(refreshToken: string): Promise<AuthTokens> {
  await delay(400);
  if (refreshToken === DUMMY_REFRESH) {
    return { accessToken: DUMMY_ACCESS_ROTATED, refreshToken: DUMMY_REFRESH };
  }
  throw new ApiError('Refresh token invalid', 401);
}

export const authApi = { login, register, refreshTokens };
