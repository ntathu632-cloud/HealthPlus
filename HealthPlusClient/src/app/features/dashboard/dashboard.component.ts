import { Component, OnInit, signal, computed } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { DatePipe } from '@angular/common';
import { AuthService } from '../../core/auth/auth.service';
import { HealthRecordService } from '../../core/services/health-record.service';
import { MedicalHistoryService } from '../../core/services/medical-history.service';
import { VaccineService } from '../../core/services/vaccine.service';
import { ReminderService } from '../../core/services/reminder.service';
import { HealthRecord } from '../../models/health-record.models';
import { MedicalHistory } from '../../models/medical-history.models';
import { Vaccine } from '../../models/vaccine.models';
import { Reminder } from '../../models/reminder.models';

interface StatCard { label: string; value: number; icon: string; bg: string; fg: string; lightBg: string; route: string; }

// Cache ở module-level (không nằm trong instance) để dữ liệu vẫn còn đó khi bấm sang
// mục khác ở sidebar rồi quay lại — tránh chớp qua trạng thái "đang tải/trống" mỗi lần
// component bị huỷ-tạo lại do điều hướng. Chỉ hiện lại spinner ở lần tải đầu tiên của
// mỗi tài khoản (so khớp userId), các lần quay lại sau đó hiện ngay dữ liệu đã có rồi
// âm thầm làm mới ở nền.
let cachedUserId: string | null = null;
const recordsCache           = signal<HealthRecord[]>([]);
const followUpsCache         = signal<MedicalHistory[]>([]);
const overdueVaccinesCache   = signal<Vaccine[]>([]);
const upcomingRemindersCache = signal<Reminder[]>([]);
const recordsLoadedOnce      = signal(false);
const followUpsLoadedOnce    = signal(false);
const vaccinesLoadedOnce     = signal(false);
const remindersLoadedOnce    = signal(false);

@Component({
    templateUrl: './dashboard.component.html',
    styleUrl: './dashboard.component.scss',
    selector: 'app-dashboard',
  standalone: true,
  imports: [RouterLink, MatIconModule, MatButtonModule, MatProgressSpinnerModule, DatePipe]
})
export class DashboardComponent implements OnInit {
  records           = recordsCache;
  followUps         = followUpsCache;
  overdueVaccines   = overdueVaccinesCache;
  upcomingReminders = upcomingRemindersCache;
  recordsLoading    = computed(() => !recordsLoadedOnce());
  followUpsLoading  = computed(() => !followUpsLoadedOnce());
  vaccinesLoading   = computed(() => !vaccinesLoadedOnce());
  remindersLoading  = computed(() => !remindersLoadedOnce());
  readonly today    = new Date();

  stats = computed<StatCard[]>(() => [
    { label: 'Hồ sơ sức khỏe',  value: this.records().length,          icon: 'person',        bg: '#1565C0', fg: '#1565C0', lightBg: '#E3F2FD', route: '/health-records' },
    { label: 'Lịch tái khám',    value: this.followUps().length,         icon: 'event_note',    bg: '#1976D2', fg: '#1976D2', lightBg: '#EFF6FF', route: '/medical-history' },
    { label: 'Vaccine quá hạn',  value: this.overdueVaccines().length,   icon: 'vaccines',      bg: '#D32F2F', fg: '#D32F2F', lightBg: '#FFEBEE', route: '/vaccines' },
    { label: 'Nhắc nhở sắp tới', value: this.upcomingReminders().length, icon: 'notifications', bg: '#1565C0', fg: '#0D47A1', lightBg: '#DBEAFE', route: '/reminders' },
  ]);

  constructor(
    public auth: AuthService,
    private healthSvc: HealthRecordService,
    private medSvc:    MedicalHistoryService,
    private vacSvc:    VaccineService,
    private remSvc:    ReminderService,
  ) {}

  ngOnInit(): void {
    const userId = this.auth.user()?.id ?? null;
    if (userId !== cachedUserId) {
      cachedUserId = userId;
      recordsCache.set([]);
      followUpsCache.set([]);
      overdueVaccinesCache.set([]);
      upcomingRemindersCache.set([]);
      recordsLoadedOnce.set(false);
      followUpsLoadedOnce.set(false);
      vaccinesLoadedOnce.set(false);
      remindersLoadedOnce.set(false);
    }

    this.healthSvc.getAll().subscribe({
      next: r => { recordsCache.set(r.data); recordsLoadedOnce.set(true); },
      error: () => recordsLoadedOnce.set(true),
    });
    this.medSvc.getUpcomingFollowUps(30).subscribe({
      next: r => { followUpsCache.set(r.data); followUpsLoadedOnce.set(true); },
      error: () => followUpsLoadedOnce.set(true),
    });
    this.vacSvc.getOverdue().subscribe({
      next: r => { overdueVaccinesCache.set(r.data); vaccinesLoadedOnce.set(true); },
      error: () => vaccinesLoadedOnce.set(true),
    });
    // 7 ngày thay vì 24h — để mục này luôn có nội dung hữu ích thay vì trống trơn
    // chỉ vì không có nhắc nhở nào rơi đúng vào ~24 giờ tới.
    this.remSvc.getUpcoming(24 * 7).subscribe({
      next: r => { upcomingRemindersCache.set(r.data); remindersLoadedOnce.set(true); },
      error: () => remindersLoadedOnce.set(true),
    });
  }

  firstName(): string {
    const name = this.auth.currentUserName() ?? '';
    return name.trim().split(' ').pop() ?? name;
  }

  daysUntil(date: string): number {
    return Math.ceil((new Date(date).getTime() - Date.now()) / 86400000);
  }
}
