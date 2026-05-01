# Parent Kehadiran — Backend Spec

## 0. Why two attendance tables now

Today the `attendances` table records **per-class-period attendance** —
one row per student per scheduled class (e.g. Matematika period 3 on
2025-10-28 → one row). That's the right shape for a subject teacher
checking their roll, but it's **not** what the parent screen needs.

The parent (and admin daily KPI) want **per-day attendance** — did the
child come to school at all today, when did they sign in at the gate,
when did they leave, were they late.

These are two genuinely different concepts. Trying to derive one from
the other is brittle (a student can be marked "hadir" in 5 of 7 classes
because the homeroom didn't take roll period 1 — was the day "hadir" or
"alpha"?). Cleaner: store both.

## 1. Schema migration — split the tables

### 1a. Rename `attendances` → `student_class_attendances`

```php
Schema::rename('attendances', 'student_class_attendances');
```

The existing model `App\Models\Attendance` is renamed to
`StudentClassAttendance`. All existing controllers, repositories, and
mixins that read per-class attendance keep their queries — only the
class name and the table name change. Because the column shape doesn't
change, no data migration is needed beyond the rename.

A search-and-replace across the codebase covers:
- `app/Models/Attendance.php` → `StudentClassAttendance.php`
- `app/Http/Controllers/AttendanceController.php` → `StudentClassAttendanceController.php`
- `app/Modules/Assessment/Repositories/AttendanceRepository.php` → `StudentClassAttendanceRepository.php`
- All `use App\Models\Attendance;` imports

### 1b. Create `student_daily_attendances`

```php
Schema::create('student_daily_attendances', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->uuid('school_id');
    $table->uuid('student_id');
    $table->date('date');
    // Status at the daily level. Derived from class_attendances OR
    // explicit gate-scan record. Values: present, late, excused, sick,
    // alpha (matches StudentClassAttendance vocab so chips reuse).
    $table->string('status');
    // Gate signals — nullable because not all schools track entry/exit
    // (small schools can leave these null and the screen shows a
    // condensed card without time).
    $table->time('check_in_time')->nullable();
    $table->time('check_out_time')->nullable();
    // Late minutes computed once at write time:
    //   late_minutes = max(0, EXTRACT(EPOCH FROM check_in_time -
    //                                 schools.start_time) / 60)
    $table->integer('late_minutes')->nullable();
    // Note + attachment for excused/sick days
    $table->text('note')->nullable();
    $table->string('attachment_url')->nullable();
    // Audit trail — who recorded this row (admin, wali kelas, gate
    // scanner system user)
    $table->uuid('recorded_by')->nullable();
    $table->timestamps();
    $table->softDeletes();

    // One row per student per day at most
    $table->unique(['student_id', 'date'], 'sda_student_date_unique');
    $table->index(['school_id', 'date']);
    $table->index(['student_id', 'date']);
});
```

### 1c. Backfill (one-time data migration)

For each school-day in the active academic year, insert a daily row
derived from the existing per-class records:

```sql
INSERT INTO student_daily_attendances (
    id, school_id, student_id, date, status, created_at, updated_at
)
SELECT
    gen_random_uuid(),
    sca.school_id,
    sca.student_id,
    sca.date::date,
    -- Derive day status: 'alpha' if every period was alpha;
    -- 'sick' if any period was sick; 'excused' if any was excused;
    -- 'late' if any was late; otherwise 'present'.
    CASE
        WHEN COUNT(*) FILTER (WHERE LOWER(sca.status) IN ('present','hadir','late','terlambat')) > 0
             AND COUNT(*) FILTER (WHERE LOWER(sca.status) IN ('late','terlambat')) > 0
        THEN 'late'
        WHEN COUNT(*) FILTER (WHERE LOWER(sca.status) IN ('present','hadir')) > 0
        THEN 'present'
        WHEN COUNT(*) FILTER (WHERE LOWER(sca.status) IN ('sick','sakit')) > 0
        THEN 'sick'
        WHEN COUNT(*) FILTER (WHERE LOWER(sca.status) IN ('excused','izin')) > 0
        THEN 'excused'
        ELSE 'alpha'
    END,
    NOW(), NOW()
FROM student_class_attendances sca
GROUP BY sca.school_id, sca.student_id, sca.date::date;
```

After backfill, going forward we keep both tables in sync via a
listener / observer:

```php
// app/Observers/StudentClassAttendanceObserver.php
public function saved(StudentClassAttendance $row): void
{
    UpsertDailyAttendanceFromClassRows::dispatch(
        $row->student_id,
        $row->date->toDateString(),
    );
}
```

The job recomputes the day-rollup and upserts the
`student_daily_attendances` row.

## 2. New endpoint

### `GET /api/parent/attendance/monthly-summary`

Powers the Parent Kehadiran main screen + the calendar full-month
screen with one fetch.

**Query params**
- `student_id` (required, UUID)
- `month` (required, `YYYY-MM`)
- `academic_year_id` (optional, defaults to active)
- `statuses[]` (optional, multi: `present,late,excused,sick,alpha`)

**Response**

```json
{
  "success": true,
  "data": {
    "student": {
      "id": "...",
      "name": "Rania Ahmad",
      "class": "8B"
    },
    "month": "2025-10",
    "school_days": 22,
    "summary": {
      "rate": 90.3,
      "present": 19,
      "excused": 2,
      "sick": 1,
      "alpha": 0,
      "late": 3
    },
    "prev_month_rate": 88.9,
    "delta_pct": 1.4,
    "days": [
      {
        "date": "2025-10-28",
        "status": "late",
        "check_in_time": "07:12",
        "check_out_time": "14:30",
        "late_minutes": 12,
        "note": "macet di jalan",
        "attachment_url": null
      }
    ]
  }
}
```

Cached in Redis with TTL 1 hour, key
`student:{student_id}:month:{YYYY-MM}`. Invalidated when the daily
observer upserts a row for that student+month.

## 3. RBAC

- Parent: read summary for their own children (linked via `students.guardian_email = user.email` OR `students.user_id = user.id`).
- Wali kelas: read for any student in their homeroom.
- Subject teacher: only the per-class table, not the daily table.
- Admin: any student in their school.

## 4. Migration order

1. Rename `attendances` → `student_class_attendances` + update PHP class names + grep callers.
2. Create `student_daily_attendances` migration.
3. Run backfill SQL (chunked by school for big tenants).
4. Add `StudentClassAttendanceObserver` to keep daily table in sync.
5. Implement `GET /parent/attendance/monthly-summary` controller + form request + RBAC policy.
6. Update Flutter `parent_attendance_controller.dart` to call the new endpoint.

## 5. Flutter wiring summary

- New service `ParentAttendanceService.getMonthlySummary(studentId, month, statuses)`.
- New model `ParentDailyAttendance` mirroring the response shape (Freezed).
- Existing `parent_attendance_screen.dart` rewritten on the new
  shared widgets (see `Parent_Phase3_Shared_Components.md`).
