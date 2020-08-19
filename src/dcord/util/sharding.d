/**
  Utilties related to Discord Guild sharding.
*/
module dcord.util.sharding;

import dcord.types;

/**
  Returns the shard number a given snowflake is on (given the number of shards), using the algorithm presented at https://discord.com/developers/docs/topics/gateway#sharding.
  Params:
    id = the Snowflake to find the shard number of
    numShards = the number of total shards
*/
ushort shardNumber(Snowflake id, ushort numShards) {
  return (id >> 22) % numShards;
}
