# # YAXArray とデータセットの作成

# ## YAXArray の作成

using YAXArrays
using DimensionalData: DimensionalData as DD
using DimensionalData
a = YAXArray(rand(10, 20, 5))

# 名前が定義されていない場合は、デフォルトの名前、つまり `Dim_1`、`Dim_2` が使用されます。
# 各ディメンションからデータを取得します
a.Dim_1
# または
getproperty(a, :Dim_1)

# `DD` `lookup` 関数を使用するとさらに良い
lookup(a, :Dim_1)

# ## 名前付き軸を使用した YAXArray の作成

# 主軸コンストラクターは `Dim` です。 ここではそれらを組み合わせて使用します
# `time`、`lon`、`lat` 軸と 2 つの変数のカテゴリ軸を作成します。

# ### 軸の定義
using Dates
axlist = (
    Dim{:time}(Date("2022-01-01"):Day(1):Date("2022-01-30")),
    Dim{:lon}(range(1, 10, length=10)),
    Dim{:lat}(range(1, 5, length=15)),
    Dim{:Variable}(["var1", "var2"])
    )
# および対応するデータ
data = rand(30, 10, 15, 2)
ds = YAXArray(axlist, data)

# ### 変数の選択

ds[Variable = At("var1"), lon = DD.Between(1,2.1)]

＃ ：：：情報
#
# YAXArray 内の要素の選択は `DimensionalData.jl` 構文を介して行われることに注意してください。
# 詳細については、(docs)[https://rafaqz.github.io/DimensionalData.jl/] を確認してください。
#
# :::



subset = ds[
    time = DD.Between( Date("2022-01-01"),  Date("2022-01-10")),
    lon=DD.Between(1,2),
    Variable = At("var2")
    ]


# ### プロパティ/属性

# YAXArray に追加のプロパティを追加することもできます。
# これは辞書を介して実行できます。

props = Dict(
    "time" => "days",
    "lon" => "longitude",
    "lat" => "latitude",
    "var1" => "first variable",
    "var2" => "second variable",
)

# 次に、プロパティを含む `yaxarray` が次のようにアセンブルされます。
ds = YAXArray(axlist, data, props)

# これらのプロパティにアクセスするには
ds.properties

# このプロパティは変数 `var1` と `var2` の両方で共有されることに注意してください。
# つまり、これは yaxarray のグローバル プロパティです。
# ただし、ほとんどの場合、各変数のプロパティを渡す必要があります。
# ここではデータセットを介してこれを行います。

# ## データセットの作成
# 最初に範囲軸を定義しましょう
axs = (
    Dim{:lon}(range(0,1, length=10)),
    Dim{:lat}(range(0,1, length=5)),
)

# データセットを組み立てるために 2 つのランダムな `YAXArrays` を追加します

t2m = YAXArray(axs, rand(10,5), Dict("units" => "K", "reference" => "your references"))
prec = YAXArray(axs, rand(10,5), Dict("units" => "mm", "reference" => "your references"))

ds = Dataset(t2m=t2m, prec= prec, num = YAXArray(rand(10)),
    properties = Dict("space"=>"lon/lat", "reference" => "your global references"))

# 使用される YAXArray は必ずしも同じ次元を共有するわけではないことに注意してください。
# したがって、プレーンな YAXArray よりも汎用性が高い場合は、Dataset を使用します。

# ### 選択した変数をデータ キューブに追加
# ディメンションを共有する変数をデータ キューブに収集できることは、
c = Cube(ds[["t2m", "prec"]])

# または単にすべての次元を共有しないもの

Cube(ds[["num"]])

# ### 変数のプロパティ

## 変数プロパティへのアクセスは次の方法で行われます。
Cube(ds[["t2m"]]).properties

＃ そして
Cube(ds[["prec"]]).properties

# データセットのグローバル プロパティには次のコマンドを使用してアクセスすることにも注意してください。
ds.properties

# 保存モードとさまざまなチャンク モードについては、[ここ]() で説明します。

