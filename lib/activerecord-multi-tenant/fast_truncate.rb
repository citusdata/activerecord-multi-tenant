# frozen_string_literal: true

# Truncates only the tables that have been modified, according to sequence
# values
# Faster alternative to DatabaseCleaner.clean_with(:truncation, pre_count: true)
module MultiTenant
  module FastTruncate
    def self.run(exclude: ['schema_migrations'])
      # This is a slightly faster version of DatabaseCleaner.clean_with(:truncation, pre_count: true)
      ActiveRecord::Base.connection.execute format(%(
      DO LANGUAGE plpgsql $$
      DECLARE
        t record;
        tables text[];
        seq_exists boolean;
        needs_truncate boolean;
      BEGIN
        FOR t IN SELECT schemaname, tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN (%s) LOOP
          EXECUTE 'SELECT EXISTS (SELECT * from pg_class c WHERE c.relkind = ''S''
           AND c.relname=''' || t.tablename || '_id_seq'')' into seq_exists;
          IF seq_exists THEN
            EXECUTE 'SELECT is_called FROM ' || t.tablename || '_id_seq' INTO needs_truncate;
          ELSE
            needs_truncate := true;
          END IF;

          IF needs_truncate THEN
            tables := array_append(tables, quote_ident(t.schemaname) || '.' || quote_ident(t.tablename));
          END IF;
        END LOOP;

        IF array_length(tables, 1) > 0 THEN
          EXECUTE 'TRUNCATE TABLE ' || array_to_string(tables, ', ') || ' RESTART IDENTITY CASCADE';
        END IF;
      END$$;), exclude.map { |t| "'#{t}'" }.join('\n'))
    end
  end
end
