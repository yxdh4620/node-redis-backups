###
# 读取和分析多个redis-cli info 信息，并对可能的问题进行报警
###

###
  需要的配置信息：
    server_name: 当前所在的服务器(报警时可使用)
    redis:
      host: -h
      port: -p

    slowlog:（慢查询报警得阀值）
      len:数量
      max_exec_time: 最大时长（如果有时长超过最大时长报警）

  项目使用setTimeout 循环, 即在本次检查完成后确定下次的检查时间？
###

###
  需要做的检查：
    slowlog: 慢查询的检查（redis返回的查询时长单位是微秒， 默认超过10毫秒的就会记入慢查询）
      1. 当前慢查询的数量（默认最大128）redis-cli -h xxx -p xxx -r 1 slowlog len
      2. 将得到的慢查询写入日志文件中  redis-cli -h xxx -p xxx -r 1 slowlog get
      3. 检查完后清除掉slowlog（方便下次检查）

    info:
      1.内存的使用情况：（used_memory 和 used_memory_peak ）
      2.持久化：（rdb_last_save_time 进行监控，了解你最近一次 dump 数据操作的时间，还可以通过对 rdb_changes_since_last_save 进行监控来知道如果这时候出现故障，你会丢失多少数据。）
      3.fork性能：(通过对 info 输出的 latest_fork_usec 进行监控来了解最近一次 fork 操作导致了多少时间的卡顿。)

  将得到的查询写入日志文件并记录时间
  如果出现异常发送邮件通知
###
