const PDFDocument = require('pdfkit');

function formatCurrency(value) {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(value || 0);
}

function buildPdfBuffer(draw) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({
      size: 'A4',
      margin: 50,
    });

    const buffers = [];

    doc.on('data', (chunk) => buffers.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(buffers)));
    doc.on('error', reject);

    draw(doc);
    doc.end();
  });
}

async function generatePaymentReceipt(payment) {
  return buildPdfBuffer((doc) => {
    doc.fontSize(24).fillColor('#3730A3').text('RentFlow', { align: 'left' });
    doc.moveDown(0.3);
    doc.fontSize(18).fillColor('#111827').text('Payment Receipt');
    doc.moveDown();

    const lines = [
      ['Receipt Number', payment.receiptNumber],
      ['Room', payment.room?.roomNumber || '-'],
      ['Tenant', payment.tenant?.fullName || '-'],
      ['Month', payment.month],
      ['Monthly Rent', formatCurrency(payment.monthlyRentDue)],
      ['Amount Paid', formatCurrency(payment.amountPaid)],
      ['Remaining', formatCurrency(payment.remainingAmount)],
      ['Payment Method', payment.paymentMethod],
      ['Payment Date', new Date(payment.paymentDate).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })],
      ['Remark', payment.remark || '-'],
      ['Recorded By', payment.recordedBy?.name || '-'],
    ];

    lines.forEach(([label, value]) => {
      doc.fontSize(11).fillColor('#475569').text(label);
      doc.fontSize(14).fillColor('#111827').text(String(value));
      doc.moveDown(0.6);
    });

    doc.moveDown();
    doc.fontSize(10).fillColor('#64748B').text(
      `Generated on ${new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })}`,
      { align: 'left' },
    );
  });
}

async function generateMonthlyCollectionReport({ month, year, payments, totals }) {
  return buildPdfBuffer((doc) => {
    doc.fontSize(24).fillColor('#3730A3').text('RentFlow');
    doc.moveDown(0.3);
    doc.fontSize(18).fillColor('#111827').text(`Monthly Collection Report - ${month}`);
    doc.fontSize(12).fillColor('#64748B').text(`Year: ${year}`);
    doc.moveDown();

    payments.forEach((payment) => {
      doc.fontSize(12).fillColor('#111827').text(
        `Room ${payment.room?.roomNumber || '-'} | ${payment.tenant?.fullName || '-'} | Paid ${formatCurrency(payment.amountPaid)} | Remaining ${formatCurrency(payment.remainingAmount)}`,
      );
      doc.moveDown(0.4);
    });

    doc.moveDown();
    doc.fontSize(14).fillColor('#111827').text(`Collected: ${formatCurrency(totals.collected)}`);
    doc.fontSize(14).fillColor('#111827').text(`Pending: ${formatCurrency(totals.pending)}`);
  });
}

module.exports = {
  formatCurrency,
  generatePaymentReceipt,
  generateMonthlyCollectionReport,
};
