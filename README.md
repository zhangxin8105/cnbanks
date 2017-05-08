# 中国银行行号库


## 如何使用

```ruby
gem 'cnbanks'

require 'cnbanks'
CNBanks.migrate # 第一次执行需要创建数据库
CNBanks.crawl # 开始爬数据
CNBanks.crawl(
    :daemonize  => true,
    :pidfile    => 'cnbanks.pid', 
    :logfile    => 'cnbanks.log',
    :type       => '402',
    :province:  => 'fujian',
    :city       => 'fuzhou'
) # 设置后台运行，指定PID文件位置，指定日志文件位置等
CNBanks.find_by_code '104881005100' # 通过银行行号查询银行信息
CNBanks.query_by_name '中国银行'     # 通过银行名称查询银行信息
CNBanks.query_by_pinyin_abbr 'zgyh' # 通过简拼查询银行信息
```

CLI:

```shell
$ cnbanks
$ Usage: cnbanks [command] [options]
$ Available Commands:
$ list    [options] List banks
$ disable [options] Disable bank
$ enable  [options] Enable bank
$ crawl   [options] Crawl data
$ stop    [options] Stop crawling
$ search  [options] Search banks via name，code，pinyin abbr
$ See 'cnbanks COMMAND --help' for more information on a specific command
```

```shell
$ cnbanks list --help
$ Usage: list [options]
$    -j, --json                       Show in JSON mode
$    -h, --help                       Show help
```

```shell
$ Usage: disable [options]
$    -t, --type TYPE_ID               Bank Type ID
$    -h, --help                       Show help
```

```shell
$ Usage: enable [options]
$    -t, --type TYPE_ID               Bank Type ID
$    -h, --help                       Show help
```

```shell
$ cnbanks crawl --help
$ Usage: crawl [options]
$    -d, --daemonize                  Run in daemonize
$    -f, --force                      Force to crawl data
$    -p, --pidfile FILE               PID file
$    -l, --logfile FILE               Log file
$    -T, --type TYPE                  Crawl with specified Bank Type ID
$    -P, --province-pinyin PINYIN     Crawl with specified province only
$    -C, --city-pinyin PINYIN         Crawl with specified city only
$    -h, --help                       Show help
```

```shell
$ cnbanks stop --help
$ Usage: stop [options]
$    -f, --force                      Force to stop crawling
$    -p, --pidfile FILE               PID file
$    -h, --help                       Show help
```

```shell
$ cnbanks search --help
$ Usage: search [options]
$    -c, --code CODE                  Find via Bank Code
$    -p, --pinyin-abbr PINYIN_ABBR    Query via PinYin abbr
$    -n, --name NAME                  Query via Bank Name
$    -o, --output FILE                Export to specified JSON file
$    -h, --help                       Show help
```
## 问题

有问题请提交至 https://github.com/songjiz/cnbanks/issues.
