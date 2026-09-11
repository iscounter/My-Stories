<?php

declare(strict_types=1);

require_once __DIR__ . '/../config.php';

final class Backup
{
    public static function save(string $table, array $data, ?string $recordId = null, string $action = 'write'): void
    {
        $dateDir = BACKUP_DIR . '/' . date('Y-m-d');
        if (!is_dir($dateDir)) {
            mkdir($dateDir, 0775, true);
        }

        $safeTable = preg_replace('/[^a-zA-Z0-9_-]/', '_', $table) ?? 'table';
        $ts = gmdate('Ymd_His');
        $idPart = $recordId ? preg_replace('/[^a-zA-Z0-9_-]/', '_', $recordId) : 'all';

        $payload = [
            'backup_at' => gmdate(DATE_ATOM),
            'table' => $table,
            'record_id' => $recordId,
            'action' => $action,
            'data' => $data,
        ];

        $filename = sprintf('%s_%s_%s.json', $safeTable, $idPart, $ts);
        $path = $dateDir . '/' . $filename;
        file_put_contents($path, json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
    }
}
