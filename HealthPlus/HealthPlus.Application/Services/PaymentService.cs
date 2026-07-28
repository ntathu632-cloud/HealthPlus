using HealthPlus.Application.DTOs.Payments;
using HealthPlus.Application.Interfaces;
using HealthPlus.Domain.Entities;
using HealthPlus.Domain.Enums;
using HealthPlus.Domain.Interfaces.Repositories;

namespace HealthPlus.Application.Services;

// Thanh toán mô phỏng (demo) — chưa nối cổng thanh toán thật (VNPay/Momo/Stripe...).
public class PaymentService : IPaymentService
{
    private readonly IUnitOfWork _uow;
    public PaymentService(IUnitOfWork uow) => _uow = uow;

    public async Task<PaymentResponse> SimulatePayAsync(Guid patientId, Guid appointmentId, CancellationToken ct = default)
    {
        var appointment = await _uow.Appointments.GetByIdAsync(appointmentId, ct)
            ?? throw new KeyNotFoundException("Không tìm thấy lịch hẹn.");
        if (appointment.PatientId != patientId)
            throw new UnauthorizedAccessException("Bạn không có quyền thanh toán cho lịch hẹn này.");
        if (appointment.IsPaid)
            throw new InvalidOperationException("Lịch hẹn này đã được thanh toán.");
        if (appointment.Fee <= 0)
            throw new InvalidOperationException("Lịch hẹn này không yêu cầu thanh toán.");

        var payment = new Payment
        {
            Id = Guid.NewGuid(),
            AppointmentId = appointment.Id,
            PatientId = patientId,
            DoctorId = appointment.DoctorId,
            Amount = appointment.Fee,
            Status = PaymentStatus.Completed,
            Method = "Demo",
            PaidAt = DateTime.UtcNow,
        };
        await _uow.Payments.AddAsync(payment, ct);

        appointment.IsPaid = true;
        _uow.Appointments.Update(appointment);

        await _uow.SaveChangesAsync(ct);

        var doctor = await _uow.Users.GetByIdAsync(appointment.DoctorId, ct);
        return Map(payment, doctor?.FullName ?? "(đã xoá)", appointment.AppointmentTime);
    }

    public async Task<IEnumerable<PaymentResponse>> GetMyPaymentsAsync(Guid patientId, CancellationToken ct = default)
    {
        var payments = (await _uow.Payments.FindAsync(p => p.PatientId == patientId, ct))
            .OrderByDescending(p => p.CreatedAt).ToList();

        var appointmentIds = payments.Select(p => p.AppointmentId).Distinct().ToList();
        var appointments = (await _uow.Appointments.FindAsync(a => appointmentIds.Contains(a.Id), ct))
            .ToDictionary(a => a.Id);

        var doctorIds = payments.Select(p => p.DoctorId).Distinct().ToList();
        var doctors = (await _uow.Users.FindAsync(u => doctorIds.Contains(u.Id), ct)).ToDictionary(u => u.Id);

        return payments.Select(p => Map(
            p,
            doctors.TryGetValue(p.DoctorId, out var doc) ? doc.FullName : "(đã xoá)",
            appointments.TryGetValue(p.AppointmentId, out var appt) ? appt.AppointmentTime : p.CreatedAt));
    }

    private static PaymentResponse Map(Payment p, string doctorName, DateTime appointmentTime) => new()
    {
        Id = p.Id,
        AppointmentId = p.AppointmentId,
        DoctorName = doctorName,
        AppointmentTime = appointmentTime,
        Amount = p.Amount,
        Status = p.Status,
        Method = p.Method,
        PaidAt = p.PaidAt,
        CreatedAt = p.CreatedAt,
    };
}
