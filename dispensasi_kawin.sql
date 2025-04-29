SET @target_year = 2025;
SET @jenis_perkara = 362;

SELECT 
  YEAR(tanggal_putusan) AS year, 
  MONTH(tanggal_putusan) AS month, 
  0 AS `masuk`, 
  0 AS `masuk_ecourt`, 
  COUNT(CASE WHEN `status_putusan_id` IN (7, 67) THEN 1 END) AS dicabut, 
  COUNT(CASE WHEN `status_putusan_id` = 62 THEN 1 END) AS dikabulkan, 
  COUNT(CASE WHEN `status_putusan_id` IN (63, 92) THEN 1 END) AS ditolak, 
  COUNT(CASE WHEN `status_putusan_id` = 64 THEN 1 END) AS tidak_diterima, 
  COUNT(CASE WHEN `status_putusan_id` IN (65, 93) THEN 1 END) AS digugurkan, 
  COUNT(CASE WHEN `status_putusan_id` = 66 THEN 1 END) AS dicoret, 
  COUNT(CASE WHEN `status_putusan_id` = 85 THEN 1 END) AS damai, 
  COUNT(CASE WHEN `status_putusan_id` NOT IN (7, 67, 62, 63, 92, 64, 65, 93, 66, 85) THEN 1 END) AS lain_lain, 
  COUNT(CASE WHEN `status_putusan_id` NOT IN (7, 67) THEN 1 END) AS jumlah_putus, 
  COUNT(CASE WHEN `status_putusan_id` IS NOT NULL THEN 1 END) AS jumlah_semua, 
  COUNT(CASE WHEN `tanggal_minutasi` IS NOT NULL THEN 1 END) AS jumlah_minutasi, 
  0 AS `persentase_ecourt` 
FROM 
  `perkara_putusan` 
  LEFT JOIN `perkara` ON `perkara_putusan`.`perkara_id` = `perkara`.`perkara_id` 
  LEFT JOIN (
    SELECT 
      `perkara_id`, 
      MIN(efiling_id) AS efiling_id 
    FROM 
      `perkara_efiling_id` 
    GROUP BY 
      `perkara_id`
  ) AS perkara_efiling_id ON `perkara_efiling_id`.`perkara_id` = `perkara`.`perkara_id` 
WHERE 
  YEAR(tanggal_putusan) = @target_year 
  AND `jenis_perkara_id` = @jenis_perkara 
GROUP BY 
  YEAR(tanggal_putusan), 
  MONTH(tanggal_putusan);
