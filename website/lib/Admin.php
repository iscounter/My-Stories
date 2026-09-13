<?php

declare(strict_types=1);

require_once __DIR__ . '/Database.php';

final class Admin
{
    private Database $db;

    public function __construct(Database $db)
    {
        $this->db = $db;
    }

    public function requireAdmin(array $currentUser): void
    {
        if (($currentUser['email'] ?? '') !== 'admin@example.com') {
            throw new RuntimeException('Admin access required.', 403);
        }
    }

    public function dashboard(): array
    {
        $stats = [
            'users' => (int) $this->db->fetchOne('SELECT COUNT(*) AS count FROM users WHERE deleted_at IS NULL')['count'],
            'stories' => (int) $this->db->fetchOne('SELECT COUNT(*) AS count FROM stories WHERE deleted_at IS NULL')['count'],
            'reports' => (int) $this->db->fetchOne('SELECT COUNT(*) AS count FROM reports')['count'],
            'notifications' => (int) $this->db->fetchOne('SELECT COUNT(*) AS count FROM notifications')['count'],
        ];

        $recentReports = $this->db->fetchAll('SELECT * FROM reports ORDER BY created_at DESC LIMIT 10');
        return ['stats' => $stats, 'recentReports' => $recentReports];
    }

    public function listReports(): array
    {
        return $this->db->fetchAll('SELECT * FROM reports ORDER BY created_at DESC');
    }

    public function resolveReport(string $reportId, string $status): array
    {
        $existing = $this->db->fetchOne('SELECT * FROM reports WHERE id = :id LIMIT 1', ['id' => $reportId]);
        if (!$existing) {
            throw new RuntimeException('Report not found.', 404);
        }

        $allowed = ['open', 'reviewed', 'resolved', 'rejected'];
        if (!in_array($status, $allowed, true)) {
            throw new InvalidArgumentException('Invalid report status.', 422);
        }

        $this->db->execute('UPDATE reports SET status = :status WHERE id = :id', ['status' => $status, 'id' => $reportId]);
        return $this->db->fetchOne('SELECT * FROM reports WHERE id = :id LIMIT 1', ['id' => $reportId]);
    }
}
