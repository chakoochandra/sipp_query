SELECT 
    ROUND(
        CASE 
            WHEN masuk_tahun_ini = 0 THEN 0
            ELSE (ecourt * 100.0 / masuk_tahun_ini)
        END, 
        2
    ) AS persentase_ecourt
FROM (
    SELECT
        COUNT(DISTINCT CASE 
            WHEN YEAR(p.tanggal_pendaftaran) = YEAR(NOW()) THEN p.perkara_id 
        END) AS masuk_tahun_ini,

        COUNT(DISTINCT CASE 
            WHEN YEAR(p.tanggal_pendaftaran) = YEAR(NOW()) AND e.efiling_id IS NOT NULL THEN p.perkara_id 
        END) AS ecourt
    FROM perkara p
    LEFT JOIN (
        SELECT 
            perkara_id, 
            MIN(efiling_id) AS efiling_id
        FROM perkara_efiling_id
        GROUP BY perkara_id
    ) e ON p.perkara_id = e.perkara_id
    WHERE p.alur_perkara_id NOT IN (112, 113, 114)
) stats;
