SELECT 
  `perkara_putusan`.`perkara_id` AS `row_id`, 
  `perkara_biaya`.`id`, 
  `perkara_biaya`.`tahapan_id`, 
  `perkara_biaya`.`perkara_id`, 
  `perkara_biaya`.`tanggal_transaksi`, 
  `perkara_biaya`.`jumlah`, 
  `perkara_biaya`.`jenis_transaksi`, 
  `perkara_biaya_jurusita`.`jurusita_id`, 
  `perkara_putusan`.`tanggal_putusan`, 
  `perkara_putusan`.`tanggal_minutasi`, 
  `perkara_putusan_pemberitahuan_putusan`.`tanggal_pemberitahuan_putusan`, 
  `perkara_putusan`.`tanggal_bht`, 
  `status_putusan`.`nama` AS `status_putusan`, 
  `perkara_putusan`.`putusan_verstek`, 
  `ef`.`efiling_id`, 
  `tm`.`tanggal_pp_setor`, 
  `tm`.`tanggal_jsp_terima`, 
  `hakim_id`, 
  CASE WHEN perkara_putusan.tanggal_bht IS NOT NULL THEN pasidoa14_joss.WorkingDaysBetween(
    perkara_putusan.tanggal_putusan, 
    perkara_putusan.tanggal_bht
  ) ELSE pasidoa14_joss.WorkingDaysBetween(
    perkara_putusan.tanggal_putusan, 
    CURRENT_DATE
  ) END AS diff_days, 
  `perkara_akta_cerai`.`tgl_akta_cerai`, 
  `perkara`.`nomor_perkara`, 
  `jenis_biaya`.`kode`, 
  `perkara_biaya`.`uraian`, 
  `jurusita`.`nama`, 
  `perkara`.`jenis_perkara_nama`, 
  `hk`.`hakim_nama`, 
  `pp`.`panitera_nama`, 
  `perkara`.`proses_terakhir_text` 
FROM 
  `perkara_putusan` 
  LEFT JOIN `perkara` ON `perkara_putusan`.`perkara_id` = `perkara`.`perkara_id` 
  LEFT JOIN `perkara_biaya` ON `perkara_putusan`.`perkara_id` = `perkara_biaya`.`perkara_id` 
  LEFT JOIN `jenis_biaya` ON `jenis_biaya`.`id` = `perkara_biaya`.`jenis_biaya_id` 
  LEFT JOIN `perkara_biaya_jurusita` ON `perkara_biaya_jurusita`.`perkara_biaya_id` = `perkara_biaya`.`id` 
  LEFT JOIN `jurusita` ON `jurusita`.`id` = `perkara_biaya_jurusita`.`jurusita_id` 
  LEFT JOIN `status_putusan` ON `perkara_putusan`.`status_putusan_id` = `status_putusan`.`id` 
  LEFT JOIN (
    SELECT 
      `hakim_id`, 
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
  ) AS hk ON `perkara_biaya`.`perkara_id` = `hk`.`perkara_id` 
  LEFT JOIN (
    SELECT 
      `panitera_id`, 
      `perkara_id`, 
      MAX(tanggal_penetapan) AS tanggal_penetapan, 
      `panitera_nama` 
    FROM 
      `perkara_panitera_pn` 
    WHERE 
      `aktif` = 'Y' 
    GROUP BY 
      `perkara_id`
  ) AS pp ON `perkara_biaya`.`perkara_id` = `pp`.`perkara_id` 
  LEFT JOIN (
    SELECT 
      `perkara_id`, 
      MIN(efiling_id) AS efiling_id 
    FROM 
      `perkara_efiling_id` 
    GROUP BY 
      `perkara_id`
  ) AS ef ON `perkara_biaya`.`perkara_id` = `ef`.`perkara_id` 
  LEFT JOIN `pasidoa14_joss`.`trans_minutation` `tm` ON `perkara_putusan`.`perkara_id` = `tm`.`perkara_id` 
  LEFT JOIN `perkara_putusan_pemberitahuan_putusan` ON `perkara_putusan`.`perkara_id` = `perkara_putusan_pemberitahuan_putusan`.`perkara_id` 
  LEFT JOIN `perkara_akta_cerai` ON `perkara_putusan`.`perkara_id` = `perkara_akta_cerai`.`perkara_id` 
WHERE 
  `perkara_biaya`.`kategori_id` = 6 
  AND YEAR(
    perkara_putusan.tanggal_putusan
  ) = '2026' 
GROUP BY 
  `perkara_putusan`.`perkara_id` 
ORDER BY 
  (
    CASE WHEN perkara_putusan_pemberitahuan_putusan.tanggal_pemberitahuan_putusan IS NULL THEN 0 ELSE 1 END
  ) ASC, 
  `perkara_putusan_pemberitahuan_putusan`.`tanggal_pemberitahuan_putusan` DESC, 
  `perkara_putusan`.`tanggal_bht` ASC, 
  `perkara_putusan`.`tanggal_putusan` ASC, 
  `perkara_putusan`.`perkara_id` ASC
