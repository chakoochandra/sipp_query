SET 
  @target_year = 2025;
SET 
  @jenis_perkara_id = 346;
-- 346 = cerai talak, 347 = cerai gugat
SELECT 
  `perkara`.`perkara_id`, 
  perkara.nomor_perkara, 
  `jenis_perkara_nama`, 
  perkara.jenis_perkara_id, 
  `tanggal_pendaftaran`, 
  `tanggal_putusan`, 
  `tanggal_minutasi`, 
  `status_putusan`.`nama` AS `status_putusan`, 
  COUNT(perkara_anak_pihak.id) AS jumlah_anak, 
  TIMESTAMPDIFF(
    YEAR, phk1.tanggal_lahir, perkara.tanggal_pendaftaran
  ) AS umur_p, 
  TIMESTAMPDIFF(
    YEAR, phk2.tanggal_lahir, perkara.tanggal_pendaftaran
  ) AS umur_t, 
  phk1.pekerjaan AS pekerjaan_p, 
  phk2.pekerjaan AS pekerjaan_t, 
  phk1.pendidikan AS pendidikan_p, 
  phk2.pendidikan AS pendidikan_t, 
  `perkara_putusan`.`putusan_verstek`, 
  `perkara`.`tahapan_terakhir_text`, 
  `perkara_hakim_pn`.`hakim_nama`, 
  `perkara_panitera_pn`.`panitera_nama`, 
  perkara.posita 
FROM 
  `perkara` 
  LEFT JOIN (
    SELECT 
      `perkara_id`, 
      MAX(tanggal_penetapan) AS tanggal_penetapan, 
      `hakim_nama` 
    FROM 
      `perkara_hakim_pn` 
    WHERE 
      `urutan` = '1' 
      AND `aktif` = 'Y' 
    GROUP BY 
      `perkara_id`
  ) AS perkara_hakim_pn ON `perkara`.`perkara_id` = `perkara_hakim_pn`.`perkara_id` 
  LEFT JOIN (
    SELECT 
      `perkara_id`, 
      MAX(tanggal_penetapan) AS tanggal_penetapan, 
      `panitera_nama` 
    FROM 
      `perkara_panitera_pn` 
    WHERE 
      `aktif` = 'Y' 
    GROUP BY 
      `perkara_id`
  ) AS perkara_panitera_pn ON `perkara`.`perkara_id` = `perkara_panitera_pn`.`perkara_id` 
  LEFT JOIN (
    SELECT 
      `perkara_id`, 
      MIN(efiling_id) AS efiling_id 
    FROM 
      `perkara_efiling_id` 
    GROUP BY 
      `perkara_id`
  ) AS perkara_efiling_id ON `perkara_efiling_id`.`perkara_id` = `perkara`.`perkara_id` 
  LEFT JOIN `perkara_putusan` ON `perkara_putusan`.`perkara_id` = `perkara`.`perkara_id` 
  LEFT JOIN `status_putusan` ON `perkara_putusan`.`status_putusan_id` = `status_putusan`.`id` 
  LEFT JOIN `perkara_penetapan` ON `perkara`.`perkara_id` = `perkara_penetapan`.`perkara_id` 
  LEFT JOIN perkara_pihak1 ON perkara_pihak1.perkara_id = perkara.perkara_id 
  LEFT JOIN pihak phk1 ON phk1.id = perkara_pihak1.pihak_id 
  LEFT JOIN perkara_pihak2 ON perkara_pihak2.perkara_id = perkara.perkara_id 
  LEFT JOIN pihak phk2 ON phk2.id = perkara_pihak2.pihak_id 
  LEFT JOIN perkara_anak_pihak ON perkara_anak_pihak.perkara_id = perkara.perkara_id 
WHERE 
  YEAR(tanggal_putusan) = @target_year 
  AND `status_putusan_id` NOT IN (7, 67) 
  AND `perkara`.`jenis_perkara_id` = @jenis_perkara_id 
GROUP BY 
  perkara.perkara_id 
ORDER BY 
  `perkara_putusan`.`tanggal_minutasi` DESC, 
  `perkara_putusan`.`tanggal_putusan` DESC, 
  `perkara`.`tanggal_pendaftaran` DESC
