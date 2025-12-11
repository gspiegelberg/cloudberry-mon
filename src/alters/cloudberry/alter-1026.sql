BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1026, 'jcmd memory data from PXF');

-- Memory stats from jcmd VM.native_memory in summary mode, does not include direct buffer memory
CREATE EXTERNAL WEB TABLE cbmon.__pxf_master_memory_stats(
        period timestamptz,
        hostname text,
        total_reserved_kb integer,
        total_committed_kb integer,
        java_heap_reserved_kb integer,
        java_heap_committed_kb integer,
        class_reserved_kb integer,
        class_committed_kb integer,
        thread_reserved_kb integer,
        thread_committed_kb integer,
        code_reserved_kb integer,
        code_committed_kb integer,
        gc_reserved_kb integer,
        gc_committed_kb integer,
        compiler_reserved_kb integer,
        compiler_committed_kb integer,
        internal_reserved_kb integer,
        internal_committed_kb integer,
        other_reserved_kb integer,
        other_committed_kb integer,
        symbol_reserved_kb integer,
        symbol_committed_kb integer,
        native_memory_tracking_reserved_kb integer,
        native_memory_tracking_committed_kb integer,
        shared_class_space_reserved_kb integer,
        shared_class_space_committed_kb integer,
        arena_chunk_reserved_kb integer,
        arena_chunk_committed_kb integer,
        logging_reserved_kb integer,
        logging_committed_kb integer,
        arguments_reserved_kb integer,
        arguments_committed_kb integer,
        module_reserved_kb integer,
        module_committed_kb integer,
        synchronizer_reserved_kb integer,
        synchronizer_committed_kb integer,
        safepoint_reserved_kb integer,
        safepoint_committed_kb integer
) EXECUTE 'python3 /usr/local/cbmon/bin/pxf_stats.py' ON MASTER
FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

-- Segment memory stats from jcmd VM.native_memory in summary mode, does not include direct buffer memory
CREATE EXTERNAL WEB TABLE cbmon.__pxf_segments_memory_stats(
        period timestamptz,
        hostname text,
        total_reserved_kb integer,
        total_committed_kb integer,
        java_heap_reserved_kb integer,
        java_heap_committed_kb integer,
        class_reserved_kb integer,
        class_committed_kb integer,
        thread_reserved_kb integer,
        thread_committed_kb integer,
        code_reserved_kb integer,
        code_committed_kb integer,
        gc_reserved_kb integer,
        gc_committed_kb integer,
        compiler_reserved_kb integer,
        compiler_committed_kb integer,
        internal_reserved_kb integer,
        internal_committed_kb integer,
        other_reserved_kb integer,
        other_committed_kb integer,
        symbol_reserved_kb integer,
        symbol_committed_kb integer,
        native_memory_tracking_reserved_kb integer,
        native_memory_tracking_committed_kb integer,
        shared_class_space_reserved_kb integer,
        shared_class_space_committed_kb integer,
        arena_chunk_reserved_kb integer,
        arena_chunk_committed_kb integer,
        logging_reserved_kb integer,
        logging_committed_kb integer,
        arguments_reserved_kb integer,
        arguments_committed_kb integer,
        module_reserved_kb integer,
        module_committed_kb integer,
        synchronizer_reserved_kb integer,
        synchronizer_committed_kb integer,
        safepoint_reserved_kb integer,
        safepoint_committed_kb integer
) EXECUTE 'python3 /usr/local/cbmon/bin/pxf_stats.py' ON HOST
FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._pxf_memory_stats AS
SELECT * FROM cbmon.__pxf_segments_memory_stats
UNION
SELECT * FROM cbmon.__pxf_master_memory_stats;

COMMIT;

/**
jcmd 1722304 VM.native_memory summary
1722304:

Native Memory Tracking:

Total: reserved=3731397KB, committed=1317037KB
-                 Java Heap (reserved=2097152KB, committed=1050624KB)
                            (mmap: reserved=2097152KB, committed=1050624KB)

-                     Class (reserved=1093365KB, committed=49909KB)
                            (classes #10081)
                            (  instance classes #9404, array classes #677)
                            (malloc=1781KB #27289)
                            (mmap: reserved=1091584KB, committed=48128KB)
                            (  Metadata:   )
                            (    reserved=43008KB, committed=41728KB)
                            (    used=40504KB)
                            (    free=1224KB)
                            (    waste=0KB =0.00%)
                            (  Class space:)
                            (    reserved=1048576KB, committed=6400KB)
                            (    used=5643KB)
                            (    free=757KB)
                            (    waste=0KB =0.00%)

-                    Thread (reserved=65927KB, committed=3415KB)
                            (thread #64)
                            (stack: reserved=65636KB, committed=3124KB)
                            (malloc=218KB #386)
                            (arena=73KB #126)

-                      Code (reserved=249442KB, committed=26402KB)
                            (malloc=1754KB #7083)
                            (mmap: reserved=247688KB, committed=24648KB)

-                        GC (reserved=199730KB, committed=160906KB)
                            (malloc=86814KB #14869)
                            (mmap: reserved=112916KB, committed=74092KB)

-                  Compiler (reserved=228KB, committed=228KB)
                            (malloc=95KB #645)
                            (arena=133KB #5)

-                  Internal (reserved=805KB, committed=805KB)
                            (malloc=773KB #2055)
                            (mmap: reserved=32KB, committed=32KB)

-                     Other (reserved=28KB, committed=28KB)
                            (malloc=28KB #3)

-                    Symbol (reserved=10458KB, committed=10458KB)
                            (malloc=9363KB #118728)
                            (arena=1095KB #1)

-    Native Memory Tracking (reserved=2762KB, committed=2762KB)
                            (malloc=18KB #236)
                            (tracking overhead=2745KB)

-        Shared class space (reserved=10888KB, committed=10888KB)
                            (mmap: reserved=10888KB, committed=10888KB)

-               Arena Chunk (reserved=218KB, committed=218KB)
                            (malloc=218KB)

-                   Logging (reserved=4KB, committed=4KB)
                            (malloc=4KB #193)

-                 Arguments (reserved=19KB, committed=19KB)
                            (malloc=19KB #498)

-                    Module (reserved=166KB, committed=166KB)
                            (malloc=166KB #1833)

-              Synchronizer (reserved=195KB, committed=195KB)
                            (malloc=195KB #1651)

-                 Safepoint (reserved=8KB, committed=8KB)
                            (mmap: reserved=8KB, committed=8KB)
**/
