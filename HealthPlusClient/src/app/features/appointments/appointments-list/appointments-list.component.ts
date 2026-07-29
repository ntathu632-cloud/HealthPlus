import { Component, OnInit, signal, computed } from '@angular/core';
import { DatePipe, DecimalPipe, NgClass } from '@angular/common';
import { RouterLink } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatChipsModule, MatChipListboxChange } from '@angular/material/chips';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { AppointmentService } from '../../../core/services/appointment.service';
import { PaymentService } from '../../../core/services/payment.service';
import { Appointment } from '../../../models/appointment.models';
import { BookAppointmentDialogComponent } from '../book-appointment-dialog/book-appointment-dialog.component';

@Component({
    templateUrl: './appointments-list.component.html',
    styleUrl: './appointments-list.component.scss',
    selector: 'app-appointments-list',
  standalone: true,
  imports: [
    DatePipe, DecimalPipe, NgClass, RouterLink,
    MatCardModule, MatButtonModule, MatIconModule, MatProgressSpinnerModule, MatTooltipModule, MatChipsModule,
  ]
})
export class AppointmentsListComponent implements OnInit {
  allItems = signal<Appointment[]>([]);
  loading = signal(true);
  payingId = signal<string | null>(null);
  selectedStatus = 'All';

  readonly statusTabs = [
    { value: 'All',       label: 'Tất cả' },
    { value: 'Pending',   label: 'Chờ xác nhận' },
    { value: 'Confirmed', label: 'Đã xác nhận' },
    { value: 'Completed', label: 'Hoàn thành' },
    { value: 'Cancelled', label: 'Đã huỷ' },
  ];

  filteredItems = computed(() => {
    if (this.selectedStatus === 'All') return this.allItems();
    return this.allItems().filter(a => a.status === this.selectedStatus);
  });

  constructor(
    private svc: AppointmentService,
    private paymentSvc: PaymentService,
    private dialog: MatDialog,
    private snack: MatSnackBar,
  ) {}

  ngOnInit(): void { this.load(); }

  load(): void {
    this.loading.set(true);
    this.svc.getMyAppointments().subscribe({
      next: res => { this.allItems.set(res.data); this.loading.set(false); },
      error: () => this.loading.set(false),
    });
  }

  onStatusFilterChange(e: MatChipListboxChange): void {
    this.selectedStatus = e.value;
  }

  countByStatus(status: string): number {
    if (status === 'All') return this.allItems().length;
    return this.allItems().filter(a => a.status === status).length;
  }

  openBook(): void {
    this.dialog.open(BookAppointmentDialogComponent, { width: '480px' })
      .afterClosed().subscribe(ok => { if (ok) this.load(); });
  }

  cancel(a: Appointment): void {
    if (!confirm(`Huỷ lịch hẹn với "${a.doctorName}"?`)) return;
    this.svc.cancel(a.id).subscribe({
      next: () => {
        this.snack.open('Đã huỷ lịch hẹn', 'Đóng', { duration: 2000 });
        this.load();
      },
      error: () => this.snack.open('Huỷ lịch hẹn thất bại', 'Đóng', { duration: 3000 }),
    });
  }

  pay(a: Appointment): void {
    this.payingId.set(a.id);
    this.paymentSvc.pay(a.id).subscribe({
      next: () => {
        this.snack.open('Thanh toán thành công (mô phỏng)', 'Đóng', { duration: 3000, panelClass: 'snack-success' });
        this.payingId.set(null);
        this.load();
      },
      error: err => {
        this.payingId.set(null);
        this.snack.open(err.error?.message ?? 'Thanh toán thất bại', 'Đóng', { duration: 3500 });
      },
    });
  }

  statusLabel(s: string): string {
    const map: Record<string, string> = {
      Pending: 'Chờ xác nhận', Confirmed: 'Đã xác nhận', Completed: 'Hoàn thành', Cancelled: 'Đã huỷ',
    };
    return map[s] ?? s;
  }
}
