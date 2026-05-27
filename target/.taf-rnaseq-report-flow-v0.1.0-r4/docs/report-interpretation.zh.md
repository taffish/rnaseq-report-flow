# RNA-seq 入门与报告解读指南

本文档面向 `taf-rnaseq-report-flow` 生成的 RNA-seq 项目报告。它既是报告解读手册，也是给 RNA-seq 新手的简明入门材料。目标不是替用户写项目结论，而是帮助用户理解每一步在回答什么生物学问题、每张图应该怎么看、哪些统计概念需要知道，以及哪些结论不能由自动报告直接给出。

## 1. RNA-seq 在回答什么问题

Bulk RNA-seq 测量一群细胞或组织中 RNA 分子的丰度。它不能直接告诉我们蛋白活性、代谢通量或因果机制，但可以回答一系列表达层面的问题：

- 这批 reads 的质量是否足够可靠？
- reads 能否稳定分配到参考转录本、基因或基因组位置？
- 样本之间是否可比，生物学重复是否一致？
- 在给定实验设计和比较条件下，哪些基因表达发生变化？
- 这些变化基因是否共同指向某些功能、通路或生物过程？
- 这些结果适合作为哪些后续验证实验或机制假设的线索？

可以把 RNA-seq 报告看成从“测序观测”走向“生物学假设”的证据链：

```text
FASTQ reads
-> QC / trimming
-> transcript or gene quantification
-> count matrix / TPM matrix
-> sample relationship and normalization checks
-> differential expression
-> enrichment
-> biological hypotheses and reusable evidence
```

报告中的每一节都应该放在这条证据链中理解。

## 2. 推荐阅读顺序

1. 先看项目总览

   查看样本数、route、已收集模块、图片数量、HTML 报告链接、DE 和 enrichment 是否存在。这个部分用于判断报告是否覆盖了你预期的分析路径。

2. 先质控，再解释生物学

   不建议一上来只看差异基因和富集条目。先确认 reads 质量、定量完整性、样本关系、比对/计数质量和表达分布是否合理。如果样本分组或分布异常，后续 DE 和 enrichment 都需要谨慎。

3. 再看差异表达

   差异表达回答的是“在当前设计矩阵和比较条件下，哪些基因的表达变化有统计证据”。它是候选基因筛选和后续机制解释的入口，但不是因果证明。

4. 最后看功能富集

   富集分析把基因层面的变化组织成 gene set 或生物过程层面的假设。它依赖基因 ID 空间、背景基因集、gene set 来源和阈值选择，不能脱离这些上下文独立解释。

## 3. 实验设计基础

### Biological replicate

生物学重复是来自同一条件的独立生物样本。它们用于估计自然生物变异，是差异表达分析的基础。RNA-seq 的差异分析不是只比较两个数值，而是比较组内变异和组间差异。

### Technical replicate

技术重复是同一生物材料的重复建库、测序或技术操作。它可以帮助评估技术噪声，但不能替代生物学重复。把技术重复当作生物学重复会高估样本量，导致过度自信的统计结果。

### Condition

Condition 是要比较的生物学状态，例如 WT、KO、control、treated、不同组织或时间点。样本表中的 condition 必须和真实实验设计一致。

### Batch

Batch 是建库日期、测序 lane、操作者、中心、试剂批次等技术因素。如果 batch 和 condition 完全绑定，例如所有 control 都在第一天做、所有 treated 都在第二天做，那么模型很难区分技术差异和生物学差异。

### Contrast

Contrast 是模型中真正要问的问题，例如 `treated vs control`、`KO vs WT`。同一个数据集可以有多个 contrast，但每个 contrast 都必须有清楚的生物学含义。

### 只有一个条件时能做什么

如果数据只有 3 个 WT，没有对照或处理组，可以做：

- reads QC；
- trimming；
- Salmon/Kallisto 表达定量；
- gene/transcript count matrix；
- TPM matrix；
- 样本相关性；
- 表达分布；
- 可选的 alignment/count/QC branch。

但不能做条件层面的差异表达，也不能做依赖差异基因列表的标准 ORA。可以做表达矩阵交付、表达谱描述、样本质量检查，或为后续加入对照组做准备。

## 4. 各模块回答的问题

### Reference preparation

参考构建模块回答：基因组、注释、转录本、`tx2gene` 和索引是否已经为下游分析准备好。

需要重点检查：

- genome 和 annotation 是否来自同一 release；
- transcript ID 和 gene ID 是否能稳定映射；
- Salmon/Kallisto index 是否用于表达定量；
- HISAT2 index 是否用于可选的 genome-aware alignment branch。

如果参考序列和注释 ID 不一致，下游定量、计数、差异和富集都会受到影响。

### Read QC and expression quantification

这个模块回答：reads 是否可用，表达定量是否完整。

主要证据包括 FastQC/MultiQC、fastp、Salmon/Kallisto summary、gene/transcript count/TPM matrix。常见关注点包括每个样本的 reads 数量、质量分布、adapter/低质量修剪情况，以及定量是否覆盖了所有样本。

### Alignment, counting, and RNA-seq QC

这是可选的 genome-aware evidence branch。它回答：reads 和基因组/注释的匹配情况是否支持表达路线，featureCounts 计数和 BAM 质量是否合理。

主要证据包括 HISAT2 比对摘要、BAM 文件索引、featureCounts assignment、RSeQC 和 Qualimap 报告。它适合用于检查 mapping rate、gene body coverage、插入片段/文库质量、注释兼容性和 count-based 分析证据。

### Differential expression

差异表达模块回答：在选定设计模型和 contrast 下，哪些基因发生变化。

主要证据包括 DESeq2 结果表、PCA、样本相关性热图、表达分布图、MA 图、火山图、DEG 数量图、heatmap 和 top genes expression plot。

阅读时建议区分两类图：

- 样本/模型前提检查：PCA、sample correlation、expression distribution、normalized count distribution；
- contrast 信号展示：volcano、MA、DEG counts、heatmap、top genes expression。

### Functional enrichment

富集模块回答：差异基因或排序基因列表是否指向某些生物过程、通路或 gene set。

ORA 从显著基因列表出发，回答某些 gene set 是否命中过多；GSEA 从完整排序基因列表出发，回答某些 gene set 是否在排序的一端富集。ORA 对显著阈值和背景基因集敏感，GSEA 对排序统计量和 gene set 定义敏感。

## 5. 深度模块解读：生物学如何落到技术证据上

### Reference：把生物学对象变成坐标和 ID

参考构建是整套 RNA-seq 分析的词汇表。基因组 FASTA 提供坐标空间，GFF/GTF 注释定义基因、转录本、外显子和父子关系，转录本 FASTA 与 `tx2gene` 表把转录本层面的证据连接回基因层面的解释。后续所有 count、TPM、DE 和 enrichment 都在这个词汇表里发生。

从生物学上说，一个 gene symbol、systematic ID、transcript ID 和 genome locus 彼此相关，但不是同一个东西。报告中出现的“某个基因变化”通常已经经历了多次映射：reads 到 transcript，transcript 到 gene，gene 到 gene set。任何一个映射环节出错，都会让最终解释偏离真正的生物学对象。

从技术上看，最重要的是确认 genome 和 annotation 来自同一 release，sequence ID 一致，`gene_id` 与 `transcript_id` 属性完整，`tx2gene` 能覆盖下游定量结果，Salmon/Kallisto index 与 HISAT2 index 都基于同一套参考。参考构建不是一次性的文件准备，而是对后续所有生物学解释边界的定义。

常见风险包括：基因组和注释版本不匹配、染色体命名不一致、注释中缺少稳定 gene ID、转录本提取失败、gene symbol 与 systematic ID 混用、富集背景基因集和表达矩阵 ID 空间不同。遇到这些问题时，下游结果可能仍然“跑通”，但生物学解释已经不稳。

### FASTQ QC：先判断观测，再谈结论

FASTQ 是原始观测层。每条 read 都是一个被采样的 RNA/cDNA 片段，加上碱基层面的不确定性。RNA-seq 报告不能直接从 FASTQ 跳到差异基因，因为必须先判断这些观测是否完整、是否属于正确样本、是否具有足够技术质量。

质量分布、接头含量、read length、GC 行为、重复率和每个样本的 reads 数量都对应真实实验过程：RNA 质量、建库效率、片段选择、测序仪状态、lane 分配和样本混样等。它们不是报告中的“前菜”，而是后续统计分析能不能被信任的基础。

FastQC、fastp 和 MultiQC 的作用是把这些观测层风险显性化。adapter contamination 可能降低有效 read 长度；低质量尾部可能影响定量；某个样本 reads 数量明显不足可能导致表达矩阵稀疏；样本整体质量异于其他重复时，PCA 可能首先分离的是技术质量而不是 condition。

因此读报告时要先问：所有样本是否都进入分析？reads 数量是否同量级？修剪是否过度？是否有单个样本质量异常？如果 QC 层面已经出现强烈异常，后面的 DE 和 enrichment 只能作为探索线索，不能直接作为稳健结论。

### Quantification：丰度是估计值

表达定量把 reads 转换成 transcript 或 gene abundance。这个过程不是直接数分子，而是在参考转录组、片段模型和分配规则下估计每个 feature 获得多少片段支持。相似 isoform、多重匹配、转录本长度、有效长度和文库大小都会影响结果。

从生物学上看，转录本层面定量有助于理解 isoform，但很多常规项目最终还是以 gene-level matrix 作为交付和解释核心。原因是 gene-level 结果通常更稳定、更容易连接到注释、差异表达和功能富集。`tximport` 和 `tx2gene` 决定 transcript evidence 如何汇总为 gene evidence。

Count、TPM 和 normalized count 不能混用。Count 更接近差异表达模型需要的统计证据；TPM 更适合描述表达丰度和样本内模式；normalized count 适合绘图和样本比较。一个基因 TPM 高不等于它一定在条件间显著变化，一个基因显著变化也不一定是最高表达基因。

解读定量结果时应关注：每个样本是否都有 quant 文件；gene/transcript matrix 的样本列是否齐全；`tx2gene` 是否造成大量 ID 丢失；样本间整体表达分布是否可比；低表达基因是否在 DE 前被合理过滤。

### Alignment branch：基因组上下文证据

轻量表达路线可以回答许多表达问题，但 genome-aware alignment 提供另一种证据层。BAM 文件保留 reads 在基因组上的坐标、剪接位点、链特异性、覆盖形态和 mapping quality，这些信息不是 Salmon/Kallisto 摘要能完整表达的。

从生物学上说，比对分支适合回答更靠近基因组结构的问题：reads 是否支持预期 exon/intron 结构？是否存在明显 3 prime 或 5 prime bias？gene body coverage 是否合理？文库链特异性是否和实验记录一致？是否有大量 reads 落在注释之外或多重比对区域？

这条分支不一定每个项目都需要，因为它带来更多计算和存储成本。但在正式交付、质量审计、异常样本排查、注释兼容性检查和 count-based evidence 补强时，它很有价值。它不是替代表达定量，而是为表达结论增加坐标层面的可追溯证据。

如果 alignment summary、RSeQC 或 Qualimap 指标异常，需要回到文库类型、参考版本、注释格式、read length、链特异性和样本来源进行解释。比对率低并不自动等于样本失败，但需要明确原因。

### Counting：reads 与注释相遇

Feature counting 问的是：已经比对到基因组的片段，按当前注释和规则应该归到哪个 feature。这个问题看似简单，实际取决于 feature type、`gene_id` 属性、overlap 规则、多重比对处理、链特异性和 ambiguous reads 策略。

从生物学上说，gene-level count 是“被当前注释捕获的转录证据”，不是所有转录活动的完整图景。未注释转录本、反义转录、重叠基因、重复区域和新 isoform 都可能被简化、合并或丢失。因此 featureCounts 矩阵的解释总是依赖注释版本和计数规则。

Assignment summary 是这一层最重要的 QC 之一。如果 assigned fragments 比例过低，可能说明参考不匹配、链特异性设置错误、注释太旧、样本污染、rRNA/非编码 RNA 比例异常，或 reads 长度/类型不适合当前 counting 策略。

正式报告中，count matrix 可以作为 DE 的输入证据，也可以和 Salmon gene counts 互相参照。但两者由不同模型产生，数值不必逐项一致；更重要的是它们是否在样本层面和主要生物学信号上相互支持。

### Differential expression：把变异放进模型

差异表达不是“样本 A 的表达量减去样本 B 的表达量”，而是把表达矩阵放进实验设计中，估计组内变异和组间差异。DESeq2 等模型会为每个基因估计离散度、表达均值、fold change 和统计显著性。

从生物学上看，真正被比较的是 condition，而不是单个样本。生物学重复用于估计自然变异；contrast 定义具体问题；design 决定模型考虑哪些因素。如果只有一个条件，模型无法做条件层面的 DE；如果 batch 和 condition 完全绑定，模型很难区分技术差异和生物学差异。

读 DE 图时要分两层。PCA、sample correlation 和 expression distribution 用来检查样本关系和模型前提；volcano、MA、DEG counts、heatmap 和 top genes expression 用来展示具体 contrast 的信号。前一层回答“数据是否适合解释”，后一层回答“变化集中在哪里”。

显著性和效应量也要一起读。`padj` 低说明统计证据强，`log2FC` 大说明变化幅度大，但二者都需要结合表达量、样本一致性、基因功能和实验背景。差异基因是候选机制入口，不是机制本身。

### Enrichment：从基因列表到生物学假设

富集分析把解释单位从单个基因转换成 gene set、pathway 或 GO term。这样做的生物学理由是，许多过程不是由单个基因孤立完成，而是由一组基因共同形成程序，例如应激反应、核糖体生成、细胞周期、转运、代谢和信号通路。

ORA 从显著基因列表出发，问某个 gene set 命中是否多于背景期望。它直观、适合汇报强信号，但对显著阈值和背景基因集很敏感。GSEA 从完整排序列表出发，问某个 gene set 的成员是否倾向于出现在排序的一端；它适合发现许多基因共同小幅变化的方向性信号。

富集结果最常见的误读是把 term 名称当作已经证明的机制。实际上，富集只是说明当前基因证据和某个已有 gene set 定义之间存在统计关联。还需要看实际 hit genes、term 层级、冗余 term、上下调方向、NES 方向和已有文献。

对 ORA 来说，背景基因集必须和“有机会被检验到的基因”一致。对 GSEA 来说，排序统计量必须稳定、方向含义必须清楚。若 ID 映射丢失严重或 GMT 来源和物种/注释版本不匹配，富集结果可能漂亮但不可靠。

### Report and provenance：可复现性也是证据

最终 RNA-seq 报告不是只给几张图，而是一个可交付、可审计、可复用的证据包。它应该说明用了哪些输入、调用了哪些流程、工具版本是什么、图片和表格来自哪里、命令和方法如何追溯。

`rnaseq-report-flow` 保留 `versions.tsv`、`commands.sh`、`methods.txt`、`plot_gallery.tsv`、`html_reports.tsv`、`tool_links.tsv` 和 `run.manifest.json`，就是为了让报告不只适合人眼浏览，也适合审计和自动化归档。

可复现性不会自动生成生物学真理，但它让讨论有据可查。当协作者问“为什么这个 term 出现”“为什么这个基因不在富集里”“这张图来自哪个步骤”“是否用了 alignment branch”时，报告应该能把问题指回具体文件和方法，而不是依赖口头记忆。

### 长文章节阅读结构

`report_interpretation.html` 中每个模块都进一步展开为长文章节。建议按以下结构阅读：

- 湿实验来源：这一步承接了哪些实验事实，例如 RNA 质量、建库方式、测序深度、样本标记、condition 和 batch。
- 生物学意义：这一步把哪个生物学问题变成了可分析对象，例如丰度、坐标、条件效应或功能过程。
- 生物学难点：真实生物系统中有哪些复杂性，例如 isoform、重复区域、样本异质性、细胞组成、GO term 冗余和基因 ID 漂移。
- 技术难点：计算上哪些选择会改变结果，例如参考版本、tx2gene、链特异性、feature counting 规则、归一化、design formula、contrast 和背景基因集。
- 流程实现：TAFFISH RNA-seq flow 用哪些上游模块和文件保存证据，例如 `reference_summary.tsv`、`quant_files.tsv`、BAM/featureCounts/RSeQC/Qualimap、DESeq2 表格、ORA/GSEA 表格和 `run.manifest.json`。
- 报告解读：用户应该在主报告中先看哪些图和表，哪些结果适合做结论，哪些只能作为后续验证假设。

这个结构的目的，是把自动报告从“文件索引”提升为“分析解释地图”。它仍然不替用户写项目特异结论，但可以帮助新手理解每一步为什么存在、它承接了什么湿实验事实、它产生了什么可审计证据，以及它能支持多强的生物学说法。

## 6. 常见统计概念

### Count

Count 是支持某个 gene 或 transcript 的 reads/fragments 数量。它适合做统计建模，但不同样本的 count 受 library size 影响，不同基因之间也受 feature length 和表达模型影响。

### TPM

TPM 是考虑转录本长度和测序深度后的表达丰度，适合展示样本内或样本间的表达水平趋势。很多差异表达模型仍然更倾向使用 count-like evidence，而不是直接用 TPM 做检验。

### Normalized count

Normalized count 是经过样本尺度因子调整后的 count，用于让样本在统计模型中更可比。它常用于 PCA、heatmap 或 top-gene expression plot。

### log2 fold change

log2FC 表示两组之间表达量变化的方向和幅度。`log2FC = 1` 大约表示 2 倍上调，`log2FC = -1` 大约表示 2 倍下调。需要同时关注效应量和显著性。

### p-value 和 adjusted p-value

p-value 是单个检验下反对零假设的证据。RNA-seq 同时检验成千上万个基因，所以需要多重检验校正。`padj` 或 FDR 更适合用来筛选显著基因。

### FDR

FDR 是 false discovery rate，表示在统计假设下控制预期假阳性比例。它不是生物学验证，也不能说明某个单独基因一定是真阳性。

### PCA

PCA 是把高维表达矩阵压缩到少数主成分，用于观察样本间主要变异。它适合发现组间分离、批次结构和离群样本，但每个主成分本身不是单个基因。

### NES

NES 是 GSEA 的 normalized enrichment score。正负方向表示 gene set 在排序列表哪一端富集，大小表示标准化后的富集强度。

## 7. 常见图表怎么看

### PCA

PCA 用低维空间展示样本间主要变异来源。理想情况下，同组生物学重复应相对接近，不同条件可在主要主成分上分开。如果样本按 batch 而不是 condition 分开，需要检查 metadata 和实验设计。

### Sample correlation heatmap

样本相关性热图用于判断重复一致性和离群样本。组内相关性过低、某个样本和所有样本都不相似，通常需要回到 QC、样本标签和实验记录中排查。

### Expression distribution

表达分布图用于查看样本的整体表达量分布是否可比。明显偏移可能来自测序深度、文库质量、归一化、过滤条件或样本本身差异。

### Volcano plot

火山图同时展示效应量和统计显著性。横轴通常是 log2FC，纵轴通常是 `-log10(padj)`。右上和左上区域常作为候选上调/下调基因来源，但不要只凭图形位置给出机制结论。

### MA plot

MA 图展示平均表达强度和 log2FC 的关系。它可以帮助观察低表达基因是否波动过大，以及整体 fold-change shrinkage 是否合理。

### DEG counts barplot

差异基因数量柱状图展示在当前阈值下，上调和下调基因数量。它适合项目概览，但不能替代逐基因表格检查。

### Heatmap 和 top genes expression

这些图展示代表性基因的表达模式。图中基因通常经过筛选或排序，颜色也常经过缩放，因此适合展示模式，不适合直接当作绝对表达量证据。

### ORA dotplot/barplot

ORA 图展示显著基因列表中哪些 gene set 命中过多。气泡大小常表示命中基因数，颜色常表示调整后的 p 值。需要同时查看背景基因集、gene set 来源和具体命中基因。

### GSEA NES plot 和 enrichment curves

NES 图展示标准化富集分数及方向。running enrichment curve 展示某个 gene set 的成员在排序基因列表中如何累积。GSEA 的价值在于不依赖硬性显著基因阈值，但它依赖稳定的全基因排序。

## 8. ORA 和 GSEA 的区别

ORA 的输入通常是显著差异基因列表。它问的是：在给定背景基因集中，某个 gene set 里的显著基因是否多于随机期望。它简单直观，但对 padj/log2FC 阈值和背景基因集非常敏感。

GSEA 的输入通常是所有基因的排序列表。它问的是：某个 gene set 的成员是否倾向出现在排序列表的一端。它不依赖硬性显著阈值，适合发现许多基因共同小幅变化的方向性信号。

因此 ORA 和 GSEA 不完全等价。它们结果不同并不一定表示错误，而可能是因为它们回答的问题不同。

## 9. 常见误读

- 显著差异基因不等于已验证生物标志物。
- 富集条目不等于机制已经被证明。
- GO term 名称相似不代表它们可以任意合并。
- p 值显著不代表效应量大，也不代表生物学重要性一定高。
- 样本数少、批次混杂或 metadata 不完整时，统计显著性需要更谨慎解释。
- 背景基因集不合适时，ORA 结果可能偏移。
- ID 映射丢失或混用 gene symbol/systematic ID 会影响 enrichment。
- 图形好看不代表实验设计没有问题。
- 报告中的自动解释不能替代对实验背景、文献和验证实验的判断。

## 10. 新手 FAQ

### 只有 3 个 WT 样本，可以用 rnaseq-standard-flow 吗？

可以用来做表达矩阵、QC 和样本关系检查。样本表中可以只有一个 condition。此时应跳过 DE/enrichment，或只使用 expression route。不能做 WT vs treatment 这类条件比较，因为没有第二个条件。

### 为什么有些基因在后续结果中不见了？

常见原因包括低表达过滤、ID 映射失败、注释范围不同、tx2gene 缺失、背景基因集过滤，或者某些工具只保留可统计建模的基因。

### 为什么 PCA 中同组样本不聚在一起？

可能是样本质量问题、样本标签错误、批次效应、真实生物差异过大，或者当前 condition 不是主要变异来源。需要回看 metadata、QC、实验记录和样本处理流程。

### 为什么富集结果很宽泛？

GO 体系中很多 term 本身就比较宽泛。尤其在大基因列表或背景设置不佳时，常出现上位概念。此时应结合具体命中基因、term 层级、GSEA 方向和文献背景解读。

### report-flow 会重新计算结果吗？

不会。`rnaseq-report-flow` 是静态收集器。它收集上游 flow 的表格、图、HTML 报告、版本、命令和方法记录，并生成项目级报告和解读页面。

## 11. 可复用文件

报告目录中的关键文件包括：

- `04_reports/rnaseq_report.html`：主报告入口；
- `04_reports/report_interpretation.html`：离线报告解读指南；
- `04_reports/project_summary.tsv`：项目级摘要；
- `04_reports/key_metrics.tsv`：用于快速汇报的关键指标；
- `04_reports/plot_gallery.tsv`：图片索引；
- `04_reports/html_reports.tsv`：MultiQC、FastQC、Qualimap 等 HTML bundle 链接；
- `04_reports/tool_links.tsv`：工具、流程和来源链接；
- `04_reports/versions.tsv`、`commands.sh`、`methods.txt`：版本、命令和方法溯源；
- `run.manifest.json`：自动化和归档用 manifest。

## 12. 解读边界

`rnaseq-report-flow` 是静态汇总和解释辅助工具。它不会重新运行 upstream analysis，不会修改上游结果，也不会替用户做最终生物学结论。正式项目交付时，应结合实验设计、样本信息、物种背景、已有文献和领域专家判断。
