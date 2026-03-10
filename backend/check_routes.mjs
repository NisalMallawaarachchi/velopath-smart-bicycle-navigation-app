import pg from 'pg';
import dotenv from 'dotenv';
import fs from 'fs';
dotenv.config();

const { Pool } = pg;
const pool = new Pool();
let output = '';
const log = (...args) => { const line = args.join(' '); console.log(line); output += line + '\n'; };

async function check() {
  try {
    const startNode = 25578;
    const endNode = 15592;

    // Directed dijkstra - full table, no bbox
    log('Test 1: Full-table directed dijkstra...');
    const directed = await pool.query(
      `SELECT COUNT(*) as cnt FROM pgr_dijkstra(
        'SELECT id, source, target, length_m AS cost, length_m AS reverse_cost FROM routing.ways WHERE source IS NOT NULL AND target IS NOT NULL',
        $1::BIGINT, $2::BIGINT, true
      )`, [startNode, endNode]
    );
    log('  Directed result:', directed.rows[0].cnt);

    // one-way stats
    const ow = await pool.query(
      `SELECT COUNT(*) FILTER (WHERE one_way = 1) as fwd, COUNT(*) FILTER (WHERE one_way = -1) as rev, COUNT(*) FILTER (WHERE one_way = 0 OR one_way IS NULL) as both, COUNT(*) as total FROM routing.ways`
    );
    log('Test 2: One-way stats:', JSON.stringify(ow.rows[0]));

    // cost columns
    const cols = await pool.query(
      `SELECT column_name FROM information_schema.columns WHERE table_schema='routing' AND table_name='ways' AND column_name IN ('cost','reverse_cost','cost_s','reverse_cost_s','one_way','length_m') ORDER BY column_name`
    );
    log('Test 3: Cost columns:', cols.rows.map(r=>r.column_name).join(', '));

    // cost_s attempt
    try {
      const cs = await pool.query(
        `SELECT COUNT(*) as cnt FROM pgr_dijkstra('SELECT id, source, target, cost_s AS cost, reverse_cost_s AS reverse_cost FROM routing.ways WHERE source IS NOT NULL AND target IS NOT NULL', $1::BIGINT, $2::BIGINT, true)`,
        [startNode, endNode]
      );
      log('Test 4: cost_s result:', cs.rows[0].cnt);
    } catch(e) { log('Test 4: cost_s error:', e.message.substring(0,200)); }

    // Check a sample of edges for negative costs
    const negCost = await pool.query(`SELECT COUNT(*) as cnt FROM routing.ways WHERE length_m <= 0`);
    log('Test 5: Edges with length_m <= 0:', negCost.rows[0].cnt);

    // edges at start
    const se = await pool.query(`SELECT id,source,target,length_m,one_way FROM routing.ways WHERE source=$1 OR target=$1 LIMIT 5`, [startNode]);
    log('Test 6: Edges at start node:', se.rows.length);
    se.rows.forEach(r => log(`  ${r.source}->${r.target} ow=${r.one_way} len=${r.length_m}`));

    // edges at end
    const ee = await pool.query(`SELECT id,source,target,length_m,one_way FROM routing.ways WHERE source=$1 OR target=$1 LIMIT 5`, [endNode]);
    log('Test 7: Edges at end node:', ee.rows.length);
    ee.rows.forEach(r => log(`  ${r.source}->${r.target} ow=${r.one_way} len=${r.length_m}`));

    fs.writeFileSync('route_debug.txt', output);
    log('\nSaved to route_debug.txt');
  } catch (err) {
    log('FATAL:', err.message);
    fs.writeFileSync('route_debug.txt', output);
  } finally { await pool.end(); }
}
check();
