const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://bstxdyyglxrrfqgohllz.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdHhkeXlnbHhycmZxZ29obGx6Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzUzMjAyNywiZXhwIjoyMDczMTA4MDI3fQ.Fl5FLK4WhBBN-RVI0eqbbkioUxJesdHky8T2TYnuR6o';
const supabase = createClient(supabaseUrl, supabaseKey);

async function check() {
  const { data: tables, error } = await supabase
    .rpc('get_all_tables'); // I might not have an rpc, let's query information_schema

  // query via rest is not easily possible for information schema.
  // Instead, let's just query the known tables.
  const knownTables = ['pl_quality_info', 'pl_germ_results', 'pl_lots', 'pl_receiving_harvest'];
  
  for (const t of knownTables) {
    const { data, error } = await supabase.from(t).select('*').limit(1);
    console.log(`\nTable ${t}:`);
    if (error) {
      console.log('Error:', error.message);
    } else {
      console.log(data ? Object.keys(data[0] || {}) : 'Empty');
      if (data && data.length > 0) {
        console.log('Sample:', data[0]);
      }
    }
  }
}

check();
