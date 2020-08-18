/**
  Utilties related to Discord Guild sharding.
*/
module dcord.util.sharding;

import dcord.types;

/// Returns the shard number a given snowflake is on (given the number of shards)
ushort shardNumber(Snowflake id, ushort numShards) {
  return (id >> 22) % numShards;
}
