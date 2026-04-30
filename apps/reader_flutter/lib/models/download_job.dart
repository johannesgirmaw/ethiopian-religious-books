class DownloadJob {
  DownloadJob({
    required this.bookId,
    required this.state,
    required this.updatedAtEpochMs,
    this.errorMessage,
  });

  final String bookId;
  final String state;
  final int updatedAtEpochMs;
  final String? errorMessage;

  Map<String, dynamic> toJson() => {
        'book_id': bookId,
        'state': state,
        'updated_at': updatedAtEpochMs,
        'error_message': errorMessage,
      };

  factory DownloadJob.fromJson(Map<String, dynamic> json) {
    return DownloadJob(
      bookId: json['book_id'] as String? ?? '',
      state: json['state'] as String? ?? 'pending',
      updatedAtEpochMs: (json['updated_at'] as num?)?.toInt() ?? 0,
      errorMessage: json['error_message'] as String?,
    );
  }
}
