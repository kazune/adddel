# adddel

2つのファイルを比較し、追加行数と削除行数を1行で返すBash製のCLIツールです。
差分の詳細は表示せず、Gitリポジトリ外のファイルも比較できます。

## 必要な環境

| 用途 | 必要なもの |
| --- | --- |
| ファイル比較 | macOSまたはLinux、Bash 3.2以上、Git 2系 |
| 配布物の生成 | Make、Bash、Git、Pandoc |
| 生成済み配布物のインストール | Make、Bash、`install` コマンド |
| 静的検査 | Make、Bash、ShellCheck |
| テスト | 配布物の生成に必要な環境、Bats |

## ビルド

Gitリポジトリのルートで実行します。
HEADから到達可能な `v数字.数字.数字` 形式のタグが必要です。

```sh
make dist
dist/bin/adddel --version
```

次のファイルを生成します。

```text
dist/
  bin/adddel
  share/man/man1/adddel.1
```

バージョンはGitタグから取得し、タグとHEADが異なる場合は `-g<commitid>` を付けます。
追跡ファイルに未コミットの変更がある場合は、コミットIDに加えて `-dirty` を付けます。
日付にはHEADのコミッター日時をUTCに変換した日付を使用します。
生成したプログラムのヘルプとバージョン表示にはGitを必要としません。

## 使い方

```text
Usage: adddel [-l | --label] [--] <OLD> <NEW>
       adddel -h | --help
       adddel --version
```

`OLD` は変更前、`NEW` は変更後のファイルです。
インストール前は `adddel` の代わりに `./dist/bin/adddel` を指定できます。

```sh
adddel old.txt new.txt
```

追加行数、半角スペース1文字（`0x20`）、削除行数の順に出力し、末尾に改行を付けます。
次は追加12行・削除5行の出力例です。

```text
12 5
```

ラベル付きで出力するには `-l` または `--label` を指定します。

```sh
adddel --label old.txt new.txt
```

```text
additions: 12, deletions: 5
```

オプションはファイル引数より前に指定します。
ハイフンで始まるファイル名には `--` を使用できます。

```sh
adddel -- -old.txt -new.txt
adddel --help
adddel --version
```

行の変更は削除と追加として数え、空白・空行の変更も集計します。
改行コードや末尾改行は補正しません。
通常ファイルを対象とし、シンボリックリンクは参照先を比較します。
Gitが行数を集計できないバイナリの差分はエラーとします。
同一内容でGitが差分なしと判定した場合は、バイナリでも `0 0` を返します。

### 終了コード

| コード | 意味 |
| --- | --- |
| `0` | 比較成功、ヘルプ表示、バージョン表示 |
| `1` | Gitが利用できない、または処理失敗 |
| `2` | 引数や入力ファイルの不備、集計不能なバイナリ |

差分があっても比較成功時は `0` で終了します。
エラー時は標準出力を空にし、標準エラー出力へ英語の診断を出します。

## インストール

`make install` は生成済みの `dist/` を配置します。
再生成は行わないため、先に `make dist` を実行してください。

```sh
make dist
make install PREFIX="$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
```

`PREFIX` の標準値は `/usr/local` です。
プログラムは `$(PREFIX)/bin/adddel` に権限 `755`、manページは `$(PREFIX)/share/man/man1/adddel.1` に権限 `644` で配置します。
同名ファイルは上書きし、配置先への書き込み権限が必要です。

パッケージ作成用の仮配置には `DESTDIR` を指定できます。

```sh
make install DESTDIR=/tmp/adddel-package PREFIX=/usr/local
```

この例では `/tmp/adddel-package/usr/local/` 以下に配置します。

### manページ

生成したmanページは次のコマンドで参照できます。

```sh
man ./dist/share/man/man1/adddel.1
```

## 開発

```sh
make check
make test
```

`make check` はShellCheckと `bash -n` による静的検査を行います。
配布物の生成やBatsの実行は行いません。
`make test` は配布物を生成し、CLI・生成処理・インストールのBatsテストを実行します。
Batsのみを実行する場合は `bats tests` を使用します。

静的検査の対象は `BASH_FILES`・`BATS_FILES`・`SHELL_FILES` で指定できます。
ShellCheckは `SHELL_FILES`、Bash構文検査は `BASH_FILES` を対象とします。

```sh
make check BASH_FILES=src/adddel BATS_FILES=tests/test_adddel.bats
```

プログラムの原本は [src/adddel](src/adddel)、manページの原本は [src/adddel.1.md](src/adddel.1.md) です。
原本を直接実行した場合、`--version` は `adddel @VERSION@` を表示します。

## ドキュメント

現在の仕様は [要件定義](docs/design.md) と [契約](docs/contract.md) を参照してください。
変更履歴・旧仕様・検討経緯などの過去の情報は [CHANGELOG.md](CHANGELOG.md) を参照してください。
