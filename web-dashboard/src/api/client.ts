import axios, { type AxiosInstance, type AxiosError } from 'axios';
import type {
  Device,
  DeviceStatus,
  Event,
  LatestTelemetryResponse,
  DeviceKeyRotateResponse,
  Session,
  SessionSummary,
  DashboardOverview,
  PaginatedResponse,
  DashboardAlert,
  Trainee,
  TraineeCreateRequest,
  Assessment,
  AssessmentRubric,
  TrainerReview,
  AssessmentCreateRequest,
  TrainerReviewRequest,
  SessionExportResponse,
} from '../types';

export interface HealthCheckResponse {
  status: string;
  timestamp: string;
}

export interface ReadyCheckResponse {
  status: string;
  database: string;
  timestamp: string;
}

export interface SystemInfoResponse {
  api_version: string;
  application_version: string;
  environment: string;
  server_utc: string;
}

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL || 'https://naadyantra.onrender.com';

class ApiClient {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: API_BASE_URL,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Request interceptor for auth token
    this.client.interceptors.request.use(
      (config) => {
        const token = localStorage.getItem('auth_token');
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error: AxiosError) => {
        if (error.response?.status === 401 && !window.location.pathname.includes('/login')) {
          localStorage.removeItem('auth_token');
          window.location.href = '/login';
        }
        return Promise.reject(error);
      }
    );
  }

  // Health and System checks
  async healthCheck(): Promise<HealthCheckResponse> {
    const response = await this.client.get<HealthCheckResponse>('/health');
    return response.data;
  }

  async readyCheck(): Promise<ReadyCheckResponse> {
    const response = await this.client.get<ReadyCheckResponse>('/ready');
    return response.data;
  }

  async getSystemInfo(): Promise<SystemInfoResponse> {
    const response = await this.client.get<SystemInfoResponse>('/api/v1/system/info');
    return response.data;
  }

  // Dashboard overview & alerts
  async getDashboardOverview(): Promise<DashboardOverview> {
    const response = await this.client.get<DashboardOverview>('/api/v1/dashboard/overview');
    return response.data;
  }

  async getDashboardAlerts(params?: {
    page?: number;
    page_size?: number;
    device_id?: string;
    alert_type?: string;
  }): Promise<PaginatedResponse<DashboardAlert>> {
    const response = await this.client.get<PaginatedResponse<DashboardAlert>>(
      '/api/v1/dashboard/alerts',
      { params }
    );
    return response.data;
  }

  async getRecordedAlertsCount(): Promise<number> {
    const response = await this.client.get<PaginatedResponse<DashboardAlert>>(
      '/api/v1/dashboard/alerts',
      { params: { page: 1, page_size: 1 } }
    );
    return response.data.total;
  }

  // Device endpoints
  async getDevices(params?: {
    page?: number;
    page_size?: number;
    is_active?: boolean;
    search?: string;
  }): Promise<PaginatedResponse<Device>> {
    const response = await this.client.get<PaginatedResponse<Device>>('/api/v1/devices', {
      params,
    });
    return response.data;
  }

  async getDevice(deviceId: string): Promise<Device> {
    const response = await this.client.get<Device>(`/api/v1/devices/${deviceId}`);
    return response.data;
  }

  async getDeviceStatus(deviceId: string): Promise<DeviceStatus> {
    const response = await this.client.get<DeviceStatus>(
      `/api/v1/devices/${deviceId}/status`
    );
    return response.data;
  }

  async getLatestTelemetry(deviceId: string, staleAfterSeconds = 30): Promise<LatestTelemetryResponse> {
    const response = await this.client.get<LatestTelemetryResponse>(
      `/api/v1/devices/${deviceId}/telemetry/latest`,
      { params: { stale_after_seconds: staleAfterSeconds } }
    );
    return response.data;
  }

  async registerDevice(data: {
    device_id: string;
    name?: string;
    device_key: string;
  }): Promise<Device> {
    const response = await this.client.post<Device>('/api/v1/devices/register', data);
    return response.data;
  }

  async rotateDeviceKey(deviceId: string): Promise<DeviceKeyRotateResponse> {
    const response = await this.client.post<DeviceKeyRotateResponse>(
      `/api/v1/devices/${deviceId}/rotate-key`
    );
    return response.data;
  }

  async deactivateDevice(deviceId: string): Promise<Device> {
    const response = await this.client.delete<Device>(`/api/v1/devices/${deviceId}`);
    return response.data;
  }

  // Events history
  async getDeviceEvents(params?: {
    device_id?: string;
    session?: number;
    trainee_id?: string;
    kind?: string;
    cause?: string;
    alert?: string;
    date_from?: string;
    date_to?: string;
    page?: number;
    page_size?: number;
  }): Promise<PaginatedResponse<Event>> {
    const response = await this.client.get<PaginatedResponse<Event>>('/api/v1/events', {
      params,
    });
    return response.data;
  }

  // Sessions endpoints
  async getSessions(params?: {
    page?: number;
    page_size?: number;
    device_id?: string;
    trainee_id?: string;
  }): Promise<PaginatedResponse<Session>> {
    const response = await this.client.get<PaginatedResponse<Session>>('/api/v1/sessions', {
      params,
    });
    return response.data;
  }

  async getSession(sessionId: number | string): Promise<Session> {
    const response = await this.client.get<Session>(`/api/v1/sessions/${sessionId}`);
    return response.data;
  }

  async getSessionSummary(sessionId: number | string): Promise<SessionSummary> {
    const response = await this.client.get<SessionSummary>(`/api/v1/sessions/${sessionId}/summary`);
    return response.data;
  }

  async exportSessionCsv(sessionId: number | string): Promise<SessionExportResponse> {
    const response = await this.client.get<SessionExportResponse>(`/api/v1/sessions/${sessionId}/export`);
    return response.data;
  }

  // Trainee endpoints
  async getTrainees(params?: {
    page?: number;
    page_size?: number;
    is_active?: boolean;
    search?: string;
    cohort?: string;
  }): Promise<PaginatedResponse<Trainee>> {
    const response = await this.client.get<PaginatedResponse<Trainee>>('/api/v1/trainees', {
      params,
    });
    return response.data;
  }

  async getTrainee(traineeId: string): Promise<Trainee> {
    const response = await this.client.get<Trainee>(`/api/v1/trainees/${traineeId}`);
    return response.data;
  }

  async createTrainee(data: TraineeCreateRequest): Promise<Trainee> {
    const response = await this.client.post<Trainee>('/api/v1/trainees', data);
    return response.data;
  }

  async getTraineeSessions(traineeId: string, params?: { page?: number; page_size?: number }): Promise<PaginatedResponse<Session>> {
    const response = await this.client.get<PaginatedResponse<Session>>(`/api/v1/trainees/${traineeId}/sessions`, {
      params,
    });
    return response.data;
  }

  async getTraineeAssessments(traineeId: string, params?: { page?: number; page_size?: number }): Promise<PaginatedResponse<Assessment>> {
    const response = await this.client.get<PaginatedResponse<Assessment>>(`/api/v1/trainees/${traineeId}/assessments`, {
      params,
    });
    return response.data;
  }

  // Assessment & Rubric endpoints
  async getAssessments(params?: {
    page?: number;
    page_size?: number;
    trainee_id?: string;
    rubric_id?: string;
    outcome?: string;
  }): Promise<PaginatedResponse<Assessment>> {
    const response = await this.client.get<PaginatedResponse<Assessment>>('/api/v1/assessments', {
      params,
    });
    return response.data;
  }

  async getAssessment(assessmentId: string): Promise<Assessment> {
    const response = await this.client.get<Assessment>(`/api/v1/assessments/${assessmentId}`);
    return response.data;
  }

  async createAssessment(data: AssessmentCreateRequest): Promise<Assessment> {
    const response = await this.client.post<Assessment>('/api/v1/assessments', data);
    return response.data;
  }

  async reviewAssessment(assessmentId: string, data: TrainerReviewRequest): Promise<TrainerReview> {
    const response = await this.client.post<TrainerReview>(`/api/v1/assessments/${assessmentId}/review`, data);
    return response.data;
  }

  async getRubrics(params?: {
    page?: number;
    page_size?: number;
    is_active?: boolean;
  }): Promise<PaginatedResponse<AssessmentRubric>> {
    const response = await this.client.get<PaginatedResponse<AssessmentRubric>>('/api/v1/assessment-rubrics', {
      params,
    });
    return response.data;
  }

  async getRubric(rubricId: string): Promise<AssessmentRubric> {
    const response = await this.client.get<AssessmentRubric>(`/api/v1/assessment-rubrics/${rubricId}`);
    return response.data;
  }

  // Authentication
  async login(username: string, password: string): Promise<{ access_token: string }> {
    const response = await this.client.post<{ access_token: string }>(
      '/api/v1/auth/login',
      { username, password }
    );
    return response.data;
  }

  async logout(): Promise<void> {
    try {
      await this.client.post('/api/v1/auth/logout');
    } catch {
      // Ignore network errors on logout
    }
  }
}

export const apiClient = new ApiClient();
