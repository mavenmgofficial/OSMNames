/*

--create triggers for partitioning
DROP TRIGGER IF EXISTS performCountryAndPartitionUpdate_polygon ON osm_polygon;
CREATE TRIGGER performCountryAndPartitionUpdate_polygon
    BEFORE UPDATE OF rank_search ON osm_polygon
    FOR EACH ROW
    EXECUTE PROCEDURE determineCountryCodeAndPartition();

DROP TRIGGER IF EXISTS performCountryAndPartitionUpdate_point ON osm_point;
CREATE TRIGGER performCountryAndPartitionUpdate_point
    BEFORE UPDATE OF rank_search ON osm_point
    FOR EACH ROW
    EXECUTE PROCEDURE determineCountryCodeAndPartition();

DROP TRIGGER IF EXISTS performCountryAndPartitionUpdate_linestring ON osm_linestring;
CREATE TRIGGER performCountryAndPartitionUpdate_linestring
    BEFORE UPDATE OF rank_search ON osm_linestring
    FOR EACH ROW
    EXECUTE PROCEDURE determineCountryCodeAndPartition();

--create triggers for merging streets
DROP TRIGGER IF EXISTS updateMergeFlagWhenLinestringInsert ON osm_merged_multi_linestring;
CREATE TRIGGER updateMergeFlagWhenLinestringInsert BEFORE INSERT ON osm_merged_multi_linestring
    FOR EACH ROW EXECUTE PROCEDURE updateMergedFlag();

--do the ranking and partitioning
UPDATE osm_polygon SET rank_search = rank_place(type, osm_id) WHERE rank_search IS NULL;
UPDATE osm_point SET rank_search = rank_place(type, osm_id) WHERE rank_search IS NULL;
UPDATE osm_linestring SET rank_search = rank_address(type, osm_id) WHERE rank_search IS NULL;

--create indexes
CREATE INDEX IF NOT EXISTS idx_osm_polygon_partition_rank ON osm_polygon (partition,rank_search);

*/

DROP TABLE IF EXISTS osm_polygon;
CREATE TABLE osm_polygon AS
(SELECT     
    id,
    osm_id,
    type,
    country_code,
    name,
    name_fr,
    name_en,
    name_de,
    name_es,
    name_ru,
    name_zh,
    wikipedia,
    admin_level,
    geometry,
    rpc.rank_search AS rank_search,
    rpc.partition AS partition,
    rpc.calculated_country_code AS calculated_country_code,
    NULL::bigint AS parent_id,
    NULL::bigint AS linked_osm_id
FROM
    osm_polygon_tmp p,
    determineRankPartitionCode(type, geometry, osm_id, country_code) AS rpc
);

DROP TABLE IF EXISTS osm_point;
CREATE TABLE osm_point AS
(SELECT
    id,
    osm_id,
    type,
    name,
    name_fr,
    name_en,
    name_de,
    name_es,
    name_ru,
    name_zh,
    wikipedia,
    admin_level,
    geometry,
    rpc.rank_search AS rank_search,
    rpc.partition AS partition,
    rpc.calculated_country_code AS calculated_country_code,
    NULL::bigint AS parent_id,
    FALSE::boolean AS linked
FROM
    osm_point_tmp,
    determineRankPartitionCode(type, geometry, osm_id, NULL) AS rpc
);
DROP TABLE osm_point_tmp;
DROP TABLE osm_polygon_tmp;


DROP TABLE IF EXISTS osm_linestring;
CREATE TABLE osm_linestring AS
(SELECT 
    id,
    osm_id,
    type,
    name,
    name_fr,
    name_en,
    name_de,
    name_es,
    name_ru,
    name_zh,
    wikipedia,
    admin_level,
    geometry,
    rpc.rank_search AS rank_search,
    rpc.partition AS partition,
    rpc.calculated_country_code AS calculated_country_code,
    NULL::bigint AS parent_id,
    FALSE::boolean AS merged
FROM
    osm_linestring_tmp,
    determineRankPartitionCode(type, geometry, NULL, NULL) AS rpc
);
DROP TABLE osm_linestring_tmp;



--create triggers for merging streets
DROP TRIGGER IF EXISTS updateMergeFlagWhenLinestringInsert ON osm_merged_multi_linestring;
CREATE TRIGGER updateMergeFlagWhenLinestringInsert BEFORE INSERT ON osm_merged_multi_linestring
    FOR EACH ROW EXECUTE PROCEDURE updateMergedFlag();

--create indexes
CREATE INDEX idx_osm_polgyon_geom ON osm_polygon USING gist (geometry);
CREATE INDEX idx_osm_point_geom ON osm_point USING gist (geometry);
CREATE INDEX idx_osm_linestring_geom ON osm_linestring USING gist (geometry);

CREATE INDEX  idx_osm_polygon_partition_rank ON osm_polygon (partition,rank_search);
CREATE INDEX  idx_osm_point_osm_id ON osm_point (osm_id);