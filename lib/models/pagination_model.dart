/// pagination_model.dart - Generic pagination wrapper models for API responses.
/// Like Laravel's `LengthAwarePaginator` but as a client-side DTO.
/// In Vue terms, this is the TypeScript generic interface you'd use to type paginated API responses.
library;

/// Holds pagination metadata returned by the backend alongside paginated data.
/// Like a Laravel Eloquent Model but simpler - just a data class with fromJson/toJson
/// (similar to a Laravel Resource or DTO).
///
/// This mirrors the `meta` or `pagination` block from Laravel's paginated JSON response:
/// ```json
/// { "total_items": 100, "current_page": 1, "per_page": 10, ... }
/// ```
///
/// Key properties:
/// - [totalItems]: Total records in the database (Laravel's `$paginator->total()`).
/// - [totalPages]: Total number of pages (Laravel's `$paginator->lastPage()`).
/// - [currentPage] / [perPage]: Current page index and page size.
/// - [hasNextPage] / [hasPrevPage]: Quick boolean checks for UI "Load More" / pagination buttons.
/// - [nextPage] / [prevPage]: Nullable page numbers for navigation.
class PaginationMeta {
  final int totalItems;
  final int totalPages;
  final int currentPage;
  final int perPage;
  final bool hasNextPage;
  final bool hasPrevPage;
  final int? nextPage;
  final int? prevPage;

  PaginationMeta({
    required this.totalItems,
    required this.totalPages,
    required this.currentPage,
    required this.perPage,
    required this.hasNextPage,
    required this.hasPrevPage,
    this.nextPage,
    this.prevPage,
  });

  /// Deserializes pagination metadata from a JSON map.
  /// Provides safe defaults (0, 1, false) for any missing keys.
  ///
  /// [json] - The `pagination` sub-object from the API response.
  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      totalItems: json['total_items'] ?? 0,
      totalPages: json['total_pages'] ?? 0,
      currentPage: json['current_page'] ?? 1,
      perPage: json['per_page'] ?? 10,
      hasNextPage: json['has_next_page'] ?? false,
      hasPrevPage: json['has_prev_page'] ?? false,
      nextPage: json['next_page'],
      prevPage: json['prev_page'],
    );
  }

  /// Serializes this pagination metadata back to a JSON map.
  /// Useful when caching or forwarding paginated data.
  Map<String, dynamic> toJson() {
    return {
      'total_items': totalItems,
      'total_pages': totalPages,
      'current_page': currentPage,
      'per_page': perPage,
      'has_next_page': hasNextPage,
      'has_prev_page': hasPrevPage,
      'next_page': nextPage,
      'prev_page': prevPage,
    };
  }
}

/// A generic wrapper for paginated API responses.
/// Like Laravel's `LengthAwarePaginator` combined with a JsonResource collection,
/// but on the client side. In Vue/TypeScript, this would be:
/// `interface PaginatedResponse<T> { success: boolean; data: T[]; pagination: PaginationMeta; }`
///
/// The generic type [T] represents the model class of each item in [data]
/// (e.g., `PaginatedResponse<Siswa>` for a paginated list of students).
///
/// Key properties:
/// - [success]: Whether the API call succeeded (like checking `response.ok` in fetch).
/// - [data]: The list of deserialized model objects for the current page.
/// - [pagination]: Metadata about total pages, current page, etc.
class PaginatedResponse<T> {
  final bool success;
  final List<T> data;
  final PaginationMeta pagination;

  PaginatedResponse({
    required this.success,
    required this.data,
    required this.pagination,
  });

  /// Deserializes a full paginated API response from JSON.
  ///
  /// [json] - The complete API response body as a map.
  /// [fromJsonT] - A factory function to deserialize each item in the `data` array
  ///   into type [T]. Like passing `Siswa.fromJson` to tell this method how to
  ///   build each item. Similar to Laravel's `Resource::collection()`.
  ///
  /// Returns a [PaginatedResponse] with a typed `List<T>` and pagination metadata.
  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginatedResponse(
      success: json['success'] ?? false,
      data: (json['data'] as List).map((item) => fromJsonT(item)).toList(),
      pagination: PaginationMeta.fromJson(json['pagination']),
    );
  }

  /// Serializes this paginated response back to a JSON map.
  ///
  /// [toJsonT] - A function to serialize each item of type [T] back to a map.
  /// Returns the full response structure with `success`, `data`, and `pagination`.
  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) {
    return {
      'success': success,
      'data': data.map((item) => toJsonT(item)).toList(),
      'pagination': pagination.toJson(),
    };
  }
}
