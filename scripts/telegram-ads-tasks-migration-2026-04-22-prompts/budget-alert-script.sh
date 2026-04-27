#!/bin/bash
# Script-gate: wake the agent ONLY when budget is dangerously low.
# Reads /workspace/global/telegram-ads/cache.json + history for burn rate.
# Outputs JSON to stdout: {"wakeAgent": true|false, "data": {...}}

CACHE=/workspace/global/telegram-ads/cache.json
HIST=/workspace/global/telegram-ads/history

node --input-type=module -e "
  import fs from 'fs';
  import path from 'path';
  let cache;
  try { cache = JSON.parse(fs.readFileSync('$CACHE','utf8')); }
  catch { console.log(JSON.stringify({wakeAgent:false, data:{reason:'no_cache'}})); process.exit(0); }
  const balance = Number(cache.balance_ton || 0);
  if (balance >= 3) {
    // Even if balance is fine, double-check burn rate
    let snaps = [];
    try {
      snaps = fs.readdirSync('$HIST').filter(f => f.endsWith('.json')).sort().slice(-7);
    } catch {}
    if (snaps.length < 2) { console.log(JSON.stringify({wakeAgent:false, data:{reason:'balance_ok_no_history', balance}})); process.exit(0); }
    const oldest = JSON.parse(fs.readFileSync(path.join('$HIST', snaps[0])));
    const newest = JSON.parse(fs.readFileSync(path.join('$HIST', snaps[snaps.length-1])));
    const spent = (Number(newest.total_spent_ton||0) - Number(oldest.total_spent_ton||0));
    const days = snaps.length - 1;
    const burnRate = days > 0 ? spent / days : 0;
    const daysLeft = burnRate > 0 ? balance / burnRate : 999;
    if (daysLeft < 7) {
      console.log(JSON.stringify({wakeAgent:true, data:{balance, burn_per_day:burnRate.toFixed(2), days_left:Math.floor(daysLeft), trigger:'low_runway'}}));
    } else {
      console.log(JSON.stringify({wakeAgent:false, data:{balance, burn_per_day:burnRate.toFixed(2), days_left:Math.floor(daysLeft), reason:'sufficient_runway'}}));
    }
  } else {
    console.log(JSON.stringify({wakeAgent:true, data:{balance, trigger:'low_balance'}}));
  }
"
