/**
 * Shared API types — mirrors the Laravel response envelope documented in
 * the Flutter README ("API Response Format").
 *
 *   Success:    { success: true,  data: T,           message?: string }
 *   Paginated:  { success: true,  data: T[], pagination: Pagination }
 *   Error:      { success: false, message: string,   errors?: Record<string, string[]> }
 */

export interface ApiSuccess<T> {
  success: true;
  data: T;
  message?: string;
}

export interface Pagination {
  total_items: number;
  total_pages: number;
  current_page: number;
  per_page: number;
  has_next_page: boolean;
  has_prev_page: boolean;
}

export interface ApiPaginated<T> {
  success: true;
  data: T[];
  pagination: Pagination;
}

export interface ApiError {
  success: false;
  message: string;
  errors?: Record<string, string[]>;
}

export type ApiResponse<T> = ApiSuccess<T> | ApiError;
