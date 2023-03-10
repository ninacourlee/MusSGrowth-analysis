## ANNUAL GROWTH AND PRIMARY PRODUCTION OF SPHAGNUM IN RAISED BOG “MUKHRINO” (FOUR-YEARS OBSERVATION: 2019-2022)

## Датасет доступен в GBIF: Filippova N., Kosykh N. 2023. Sphagnum annual growth and primary production measurements (Mukhrino field station, West Siberia) (2018-2022). Version 1.12. Yugra State University Biological Collection (YSU BC). Occurrence dataset. DOI: 10.15468/fcz7at 

## Необходимые пакеты
library(magrittr)
library(tidyverse)
library(stats)
library(ggplot2)
library(ggpubr)
library(rstatix)
library(ggcorrplot)
library(corrplot)
library(reshape)
library(purrr)
library(rgbif)

## скачиваем данные с помощью пакета rgbif
musgrowthdb <- read.delim("~/musgrowthdb.csv")

#===========
## ОБЩАЯ СТРУКТУРА ДАННЫХ

str(musgrowthdb) #общая структура таблицы
musgrowthdb$Year <-  as.factor(musgrowthdb$Year) #представим года в виде фактора для дальнейших анализов

# отделим измерения прироста
musgrowth <- musgrowthdb %>% 
  filter(organismQuantityType == "growth increment, cm")

# отделим экспериментальные площадки от фоновых
withoutotc <- musgrowth %>% 
  filter(occurrenceRemarks != "OTC")

withotc <- musgrowth %>% 
  filter(occurrenceRemarks == c("OTC", "control"))

withoutexperiment <- musgrowth[musgrowth$occurrenceRemarks != "OTC"&musgrowth$occurrenceRemarks != "control",]

#подсчитаем первичную продукцию
meangrowth <- musgrowth %>% 
  group_by(eventID,Year) %>% 
  summarise(mean_growth=mean(organismQuantity))

musproduct1 <- musgrowthdb %>% 
  filter(organismQuantityType == "weight of 3 cm shoots per 1 dm^2")

musproduct <- left_join(musproduct1, meangrowth, by = c("eventID", "Year")) %>% 
  mutate(product = organismQuantity / 3 * mean_growth)

productwithotc <- musproduct %>% 
  filter(occurrenceRemarks == c("OTC", "control"))

productwithoutotc <- musproduct %>% 
  filter(occurrenceRemarks != c("OTC", "control"))

# оценим нормальность распределений
# Рисунок 4. Диаграммы рассеяния (geom_density, ggplot), демонстрирующие правосторонний скос распределения годовых приростов сфагнума по годам (вверху) и по видам (внизу) на площадках стационара Мухрино за четырехлетний период мониторинга.
fig4a <- musgrowth %>% 
  ggplot(aes(x = log(organismQuantity), fill = Year))+ 
  geom_density(alpha = 0.5)+
  scale_fill_brewer(palette="Spectral")+
  labs(x = "", y = "")+
  theme_minimal()+
  theme(legend.title = element_blank())+
  theme(legend.position = c(0.16, 0.72))+
  theme(axis.text.y = element_text(size = 15))+
  theme(axis.text.x = element_text(size = 15))

fig4b <- musgrowth %>% 
  ggplot(aes(x = log(organismQuantity), fill = scientificName)) + 
  geom_density(alpha = 0.5)+
  scale_fill_brewer(palette="Spectral")+
  theme(legend.title = element_blank())+
  labs(x = "", y = "")+
  theme_minimal()+
  theme(legend.title = element_blank())+
  theme(legend.position = c(0.19, 0.63))+
  theme(axis.text.y = element_text(size = 15))+
  theme(axis.text.x = element_text(size = 15))
  
figure4 <- ggarrange(fig4a, fig4b, ncol = 1, nrow = 2)

annotate_figure(
  figure4,
  bottom = text_grob("Annual growth increment, cm, log-transformed", y= 1, hjust = 0.5, size = 15),
  left = text_grob("Density", x= 1, size = 15, rot = 90)
)

# проверим нормальность с помощью теста Шапиро-Вилкоксона
shapiro.test(musgrowth$organismQuantity) # >> распределение не нормальное (W = 0.88686, p-value < 2.2e-16)

# попробуем убрать значения "0"
test1 <- musgrowth %>% 
  filter(organismQuantity != 0)

shapiro.test(test1$organismQuantity) #>> распределение все равно не нормальное W = 0.87275, p-value < 2.2e-16

# попробуем логарифмировать
shapiro.test(log(test1$organismQuantity)) #>> распределение остается не нормальным W = 0.96934, p-value < 2.2e-16

# проверим, не будут ли распределения нормальными по отдельным годам
shapiro.test(musgrowth$organismQuantity[musgrowth$Year == 2022]) #W = 0.89106, p-value = 7.466e-15
shapiro.test(musgrowth$organismQuantity[musgrowth$Year == 2021]) #W = 0.94819, p-value = 1.178e-10
shapiro.test(musgrowth$organismQuantity[musgrowth$Year == 2020]) #W = 0.88727, p-value < 2.2e-16
shapiro.test(musgrowth$organismQuantity[musgrowthh$Year == 2019]) #W = 0.8624, p-value < 2.2e-16
# >> все года имеют ненормальные распределения

# проверим на нормальность распределения данные первичной продукции
shapiro.test(musproduct$organismQuantity) #W = 0.98265, p-value = 0.01431 и в данном случае распределение близко к нормальному

musproduct %>% 
  ggplot(aes(x = log(organismQuantity), fill = Year))+ 
  geom_density(alpha = 0.5)+
  scale_fill_brewer(palette="Spectral")+
  labs(x = "", y = "")+
  theme_minimal()+
  theme(legend.title = element_blank())+
  theme(legend.position = c(0.16, 0.72))

# >> таким образом, далее в анализе используем статистические методы для ненормальных распределений

#===========
#ВИЗУАЛИЗАЦИЯ ОБЩЕЙ СТРУКТУРЫ ДАННЫХ

#Рисунок 3. Описательные статистики, представляющие общее число полученных измерений прироста сфагнума и первичной продукции по годам, видам, типам местообитаний, экспериментальным условиям и методам измерений на площадках стационара Мухрино за четырехлетний период мониторинга. А-D: прирост сфагнума, E-F: первичная продукция.
# столбиковая диаграмма: число измерений прироста по годам, заливка по разным видам сфагнума
fig3a <- musgrowth %>%
  ggplot(aes(x = Year, fill = scientificName)) + 
  labs(x = "", y = "")+
  geom_bar()+
  scale_fill_brewer(palette="Spectral", labels = c("S. angustoflolium",
                                                   "S. balticum", "S. capillifolium", "S. fuscum",
                                                   "S. jensenii", "S. magellanicum", "S. majus", "S. papillosum"))+
  theme_minimal ()+
  theme(legend.title = element_blank())+
  theme(legend.position = c(0.7, 0.58))+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13)) 


# столбиковая диаграмма: число измерений прироста по годам, заливка по местообитаниям
fig3b <- withoutotc %>% 
  ggplot(aes(x = Year, fill = habitat)) + 
  labs(x = "", y = "")+
  geom_bar()+
  scale_fill_brewer(palette="Spectral",labels = c("Gramonoid-Er-Sphagnum bog", "Graminoid-Sphagnum bog", "Treed bog"))+
  theme_minimal()+
  theme(legend.title = element_blank())+
  theme(legend.position = c(0.75, 0.85))+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13))

# столбиковая диаграмма: число измерений прироста по годам, заливка по разным экспериментальным условиям
fig3c <- withotc %>% 
  ggplot(aes(x = Year, fill = occurrenceRemarks)) + 
  labs(x = "", y = "")+
  geom_bar()+
  scale_fill_brewer(palette="Spectral", labels = c("Control plots", "Open Top Chambers plots"))+
  theme_minimal()+
  theme(legend.title = element_blank())+
  theme(legend.position = c(0.75, 0.92))+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13))

# столбиковая диаграмма: число измерений прироста по годам, заливка по разным типам измерений
fig3d <- withoutotc %>% 
  ggplot(aes(x = Year, fill = samplingProtocol)) + 
  labs(x = "", y = "")+
  geom_bar()+
  scale_fill_brewer(palette="Spectral",labels = c("Crancked wire", "Individual ringlet"))+
  theme_minimal()+
  theme(legend.title = element_blank())+
  theme(legend.position = c(0.65, 0.92))+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13))

# столбиковая диаграмма: число измерений первичной продукции по годам, заливка по разным видам сфагнума
fig3e <- musproduct %>%
  ggplot(aes(x = Year, fill = scientificName)) + 
  labs(x = "", y = "")+
  geom_bar()+
  scale_fill_brewer(palette="Spectral", labels = c("S. angustoflolium",
                                                   "S. balticum", "S. capillifolium", "S. fuscum",
                                                   "S. jensenii", "S. magellanicum", "S. majus", "S. papillosum"))+
  theme_minimal ()+
  theme(legend.title = element_blank())+
  theme(legend.position = c(0.7, 0.65))+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13))

# столбиковая диаграмма: число измерений первичной продукции по годам, заливка по разным типам экспериментальных условий
fig3f <- productwithotc %>% 
  ggplot(aes(x = Year, fill = occurrenceRemarks)) + 
  labs(x = "", y = "")+
  geom_bar()+
  scale_fill_brewer(palette="Spectral", labels = c("Control plots", "Open Top Chambers plots"))+
  theme_minimal()+
  theme(legend.title = element_blank())+
  theme(legend.position = c(0.71, 0.93))+
  theme(axis.text.y = element_text(size = 15))+
  theme(axis.text.x = element_text(size = 15))

figure3 <- ggarrange(fig3a, fig3b, fig3c, fig3d, fig3e, fig3f, ncol = 2, nrow = 3)

annotate_figure(
  figure3,
  bottom = text_grob("Years", y= 1, hjust = 0.5, size = 15),
  left = text_grob("Total numer of measurements", x= 0.4, size = 15, rot = 90)
)

# посчитаем основные статистики прироста (среднее, стандартное отклонение) и представим их в виде таблицы в статье
# Таблица 3. Средние значения прироста со стандартными отклонениями (sd) на площадках стационара Мухрино за четырехлетний период мониторинга.
growth_mean_sd <- musgrowth %>% 
  group_by(scientificName, Year) %>% 
  summarise(sd = sd(organismQuantity), mean = mean(organismQuantity))

write.csv(growth_mean_sd, "Table 3.csv")

# посчитаем основные статистики продукции (среднее, стандартное отклонение) и представим их в виде таблицы в статье
# Таблица 5. Средние значения первичной продукции со стандартными отклонениями (sd) на площадках стационара Мухрино за четырехлетний период мониторинга.

product_mean_sd <- productwithoutotc %>% 
  group_by(scientificName, Year) %>% 
  summarise(sd = sd(organismQuantity), mean = mean(organismQuantity))

write.csv(product_mean_sd, "Table 5.csv")

#===========
#ПРОВЕРЯЕМ НАШИ ГИПОТЕЗЫ О ВЛИЯНИИ РАЗНЫХ ПАРАМЕТРОВ НА ПРИРОСТ И ПЕРВИЧНУЮ ПРОДУКЦИЮ

# используем дисперсионный анализ, чтобы оценить влияние разных факторов на прирост
# общая дисперсия для все параметров и их взаимодействий

aov_musgrowth <- aov(organismQuantity ~ scientificName * Year * habitat * fieldNotes * occurrenceRemarks, data = musgrowth)
summary(aov_musgrowth) #scientificName and year and interactions

# выводим результаты дисперсионного анализа в виде таблицы для статьи
# Таблица 2.Результаты множественного дисперсионного анализа (aov, stats), показывающие значимое влияние нескольких параметров и их взаимодействия на годовой прирост сфагнума.
Table2 <- write.csv(anova_summary(aov_musgrowth, effect.size = "ges", detailed = FALSE, observed = NULL), file = "Table 2.csv")

#для надежности, проверим достоверность влияния параметров непараметрическим аналогом дисперсионного анализа по Краселу-Уоллесу
kruskal.test(organismQuantity ~ scientificName, data = musgrowth) 
#Kruskal-Wallis chi-squared = 184.23, df = 7, p-value < 2.2e-16
kruskal.test(organismQuantity ~ Year, data = musgrowth)
#Kruskal-Wallis chi-squared = 112.87, df = 3, p-value < 2.2e-16
kruskal.test(organismQuantity ~ habitat, data = musgrowth) 
#Kruskal-Wallis chi-squared = 43.984, df = 2, p-value = 2.811e-10
kruskal.test(organismQuantity ~ fieldNotes, data = musgrowth)
#Kruskal-Wallis chi-squared = 287.92, df = 23, p-value < 2.2e-16
kruskal.test(organismQuantity ~ occurrenceRemarks, data =musgrowth)
#Kruskal-Wallis chi-squared = 21.707, df = 2, p-value = 1.934e-05

# различия между видами сфагнума визуализируем
# Рисунок 5. Диаграммы размаха (geom_boxplot, ggplot), демонстрирующие различия прироста между видами сфагнума и по годам на площадках стационара Мухрино за четырехлетний период мониторинга.
ggplot(musgrowth, aes (x = organismQuantity, y = scientificName, fill = Year))+
  geom_boxplot(alpha = 0.5)+
  scale_fill_brewer(palette="Spectral")+
  labs(x = "Growth increment, cm", y = "Species")+
  scale_color_discrete(name="")+
  theme_minimal()+
  theme(legend.title=element_blank(), legend.position = c(0.8, 0.9))+
  theme(axis.text.y = element_text(size = 15))+
  theme(axis.text.x = element_text(size = 15))+
  theme(axis.title.y = element_text(size = 15))+
  theme(axis.title.x = element_text(size = 15))

# построим матрицу вероятности различий между видами с помощью теста Вилкоксона
сorrspecies <- pairwise.wilcox.test(musgrowth$organismQuantity, musgrowth$scientificName)
сorrspeciesproduct <- pairwise.wilcox.test(musproduct$organismQuantity, musproduct$scientificName)

#Рисунок 6. Матрица различий в приросте (А) и первичной продукции (В) между видами, построенная с использованием критерия Вилкоксона, p-значения были преобразованы (-log10), чтобы визуализировать разницу: чем больше значение, тем больше различие (ноль – различия недостоверны).
# с помощью corrplot, лог-трансформированная шкала
par(mfrow=c(1,2))

# матрица для прироста
corrplot(as.matrix(-log10(сorrspecies$p.value)), type = 'lower', addCoef.col = 'red', p.mat = NULL, tl.col = "black",  
         number.digits = 0, is.corr = F, method = "circle", addrect = "0", mar = c(1, 1, 3, 1), main="", cl.pos = 'n')
# матрица для первичной продукции
corrplot(as.matrix(-log10(сorrspeciesproduct$p.value)), type = 'lower', addCoef.col = 'red', p.mat = NULL, tl.col = "black",  
         number.digits = 0, is.corr = F, method = "circle", addrect = "0", mar = c(1, 1, 3, 1), main="", cl.pos = 'n')


# Влияет ли год на прирост в целом? оценим с помощью парного теста Вилкоксона
growthyearwilcox <- pairwise.wilcox.test(withoutexperiment$organismQuantity, withoutexperiment$Year, 
                                paired = FALSE, exact=FALSE)

# создадим таблицу для экспорта значений теста Вилкоксона
# Таблица 4. Значение уровня значимости среднего прироста сфагнума между годами, полученные в результате теста Вилкоксона.
Table4 <- write.csv(data.frame(growthyearwilcox$p.value), "Table 4.csv")

# как влияет год для каждого вида сфагнума по отдельности
# Рисунок 7. Матрицы различий годового прироста разных видов сфагнума, построенные с использованием критерия Вилкоксона, p-значения были преобразованы (-log10), чтобы показать разницу, 0 - незначительная разница.
s_balt <- musgrowth %>% 
  filter(scientificName == "Sphagnum balticum"& occurrenceRemarks != c("OTC", "control"))
s_ang <- musgrowth %>% 
  filter(scientificName == "Sphagnum angustifolium")
s_maj <- musgrowth %>% 
  filter(scientificName == "Sphagnum majus")
s_cap <- musgrowth %>% 
  filter(scientificName == "Sphagnum capillifolium")
s_pap <- musgrowth %>% 
  filter(scientificName == "Sphagnum papillosum")
s_jen <- musgrowth %>% 
  filter(scientificName == "Sphagnum jensenii")
s_mag <- musgrowth %>% 
  filter(scientificName == "Sphagnum magellanicum")
s_fusc <- musgrowth %>% 
  filter(scientificName == "Sphagnum fuscum")

wil_balt <- pairwise.wilcox.test(s_balt$organismQuantity, s_balt$Year, paired = FALSE, exact=FALSE)
wil_ang <- pairwise.wilcox.test(s_ang$organismQuantity, s_ang$Year, paired = FALSE, exact=FALSE)
wil_cap <- pairwise.wilcox.test(s_cap$organismQuantity, s_cap$Year, paired = FALSE, exact=FALSE)
wil_pap <- pairwise.wilcox.test(s_pap$organismQuantity, s_pap$Year, paired = FALSE, exact=FALSE)
wil_jen <- pairwise.wilcox.test(s_jen$organismQuantity, s_jen$Year, paired = FALSE, exact=FALSE)
wil_mag <- pairwise.wilcox.test(s_mag$organismQuantity, s_mag$Year, paired = FALSE, exact=FALSE)
wil_fus <- pairwise.wilcox.test(s_fusc$organismQuantity, s_fusc$Year, paired = FALSE, exact=FALSE)
wil_maj <- pairwise.wilcox.test(s_maj$organismQuantity, s_maj$Year, paired = FALSE, exact=FALSE)
wil_all <- pairwise.wilcox.test(withoutexperiment$organismQuantity, withoutexperiment$Year, 
                                paired = FALSE, exact=FALSE)

# Рисунок 7. Матрицы различий годового прироста разных видов сфагнума, построенные с использованием критерия Вилкоксона, p-значения были преобразованы (-log10), чтобы показать разницу, 0 - незначительная разница.

par(mfrow=c(3,3))
corrplot(as.matrix(-log10(wil_balt$p.value)), tl.cex = 1.5, number.cex = 1.5, type = 'lower', addCoef.col = 'red', p.mat = NULL, tl.col = "black",  number.digits = 1, is.corr = F, method = "circle", addrect = "0", mar = c(1, 1, 3, 1), cl.pos = 'n', main="S balt")
corrplot(as.matrix(-log10(wil_ang$p.value)), tl.cex = 1.5, number.cex = 1.5,type = 'lower', addCoef.col = 'red', p.mat = NULL, tl.col = "black",  number.digits = 1, is.corr = F, method = "circle", addrect = "0", mar = c(1, 1, 3, 1), cl.pos = 'n', main="S ang")
corrplot(as.matrix(-log10(wil_cap$p.value)), tl.cex = 1.5, number.cex = 1.5,type = 'lower', addCoef.col = 'red', p.mat = NULL, tl.col = "black",  number.digits = 1, is.corr = F, method = "circle", addrect = "0", mar = c(1, 1, 3, 1), cl.pos = 'n', main="S cap")
corrplot(as.matrix(-log10(wil_pap$p.value)), tl.cex = 1.5, number.cex = 1.5,type = 'lower', addCoef.col = 'red', p.mat = NULL, tl.col = "black",  number.digits = 1, is.corr = F, method = "circle", addrect = "0", mar = c(1, 1, 3, 1), cl.pos = 'n', main="S pap")
corrplot(as.matrix(-log10(wil_jen$p.value)), tl.cex = 1.5, number.cex = 1.5,type = 'lower', addCoef.col = 'red', p.mat = NULL, tl.col = "black",  number.digits = 1, is.corr = F, method = "circle", addrect = "0", mar = c(1, 1, 3, 1), cl.pos = 'n', main="S jen")
corrplot(as.matrix(-log10(wil_mag$p.value)), tl.cex = 1.5, number.cex = 1.5,type = 'lower', addCoef.col = 'red', p.mat = NULL, tl.col = "black",  number.digits = 1, is.corr = F, method = "circle", addrect = "0", mar = c(1, 1, 3, 1), cl.pos = 'n', main="S mag")
corrplot(as.matrix(-log10(wil_fus$p.value)), tl.cex = 1.5, number.cex = 1.5,type = 'lower', addCoef.col = 'red', p.mat = NULL, tl.col = "black",  number.digits = 1, is.corr = F, method = "circle", addrect = "0", mar = c(1, 1, 3, 1), cl.pos = 'n', main="S fus")
corrplot(as.matrix(-log10(wil_maj$p.value)), tl.cex = 1.5, number.cex = 1.5,type = 'lower', addCoef.col = 'red', p.mat = NULL, tl.col = "black",  number.digits = 1, is.corr = F, method = "circle", addrect = "0", mar = c(1, 1, 3, 1), cl.pos = 'n', main="S maj")
corrplot(as.matrix(-log10(wil_all$p.value)), tl.cex = 1.5, number.cex = 1.5,type = 'lower', addCoef.col = 'red', p.mat = NULL, tl.col = "black",  number.digits = 1, is.corr = F, method = "circle", addrect = "0", mar = c(1, 1, 3, 1), cl.pos = 'n', main="All species together")


# определяет ли УБВ прирост (все вместе и по отдельным видам)?

# все виды вместе
cor.test(withoutotc$organismQuantity, withoutotc$fieldNotes) #p-value = 3.642e-06

# по отдельным видам (! статистически значимое влияние)
cor.test(s_balt$organismQuantity, s_balt$fieldNotes) #! p-value = 0.07262
cor.test(s_ang$organismQuantity, s_ang$fieldNotes) #! p-value = 7.937e-12
cor.test(s_cap$organismQuantity, s_cap$fieldNotes) # p-value = 0.1848
cor.test(s_pap$organismQuantity, s_pap$fieldNotes) #! p-value = 5.569e-06
cor.test(s_jen$organismQuantity, s_jen$fieldNotes) # p-value = 0.4637
cor.test(s_mag$organismQuantity, s_mag$fieldNotes) #! p-value = 0.0002348
cor.test(s_fusc$organismQuantity, s_fusc$fieldNotes) # p-value = 0.2394
cor.test(s_maj$organismQuantity, s_maj$fieldNotes) # p-value = 0.681

# визуализируем влияние УБВ по отдельным видам
# Рисунок 8. Графики корреляции уровня болотных вод (ось х) и прироста разных видов сфагнума (ось y), на основе метода Пирсона (corr.test) при помощи визуализации geom_point и geom_smooth функции ggplot.
fig8a <- ggplot(s_balt, aes(fieldNotes, organismQuantity))+
  geom_point()+
  ggtitle("S balticum") +
  theme_minimal()+
  theme(plot.title = element_text(hjust = 0.5, face = "italic", size = 11)) +
  xlab("") + 
  ylab("")+
  geom_smooth(col="red", method = "lm")+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13)) 

fig8b <- ggplot(s_ang, aes(fieldNotes, organismQuantity))+
  geom_point()+
  ggtitle("S angustifolium") +
  theme_minimal()+
  theme(plot.title = element_text(hjust = 0.5, face = "italic", size = 11)) +
  xlab("") + 
  ylab("")+
  geom_smooth(col="red", method = "lm")+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13)) 

fig8c <- ggplot(s_cap, aes(fieldNotes, organismQuantity))+
  geom_point()+
  ggtitle("S capillifolium") +
  theme_minimal()+
  theme(plot.title = element_text(hjust = 0.5, face = "italic", size = 11)) +
  xlab("") + 
  ylab("")+
  geom_smooth(method = "lm")+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13)) 

fig8d <- ggplot(s_pap, aes(fieldNotes, organismQuantity))+
  geom_point()+
  ggtitle("S papillifolium") +
  theme_minimal()+
  theme(plot.title = element_text(hjust = 0.5, face = "italic", size = 11)) +
  xlab("") + 
  ylab("")+
  geom_smooth(col="red", method = "lm")+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13)) 

fig8e <- ggplot(s_jen, aes(fieldNotes, organismQuantity))+
  geom_point()+
  ggtitle("S jenseni") +
  theme_minimal()+
  theme(plot.title = element_text(hjust = 0.5, face = "italic", size = 11)) +
  xlab("") + 
  ylab("")+
  geom_smooth(method = "lm")+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13)) 

fig8e <- ggplot(s_mag, aes(fieldNotes, organismQuantity))+
  geom_point()+
  ggtitle("S magellanicum") +
  theme_minimal()+
  theme(plot.title = element_text(hjust = 0.5, face = "italic", size = 11)) +
  xlab("") + 
  ylab("")+
  geom_smooth(col="red", method = "lm")+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13)) 

fig8f <- ggplot(s_fusc, aes(fieldNotes, organismQuantity))+
  geom_point()+
  ggtitle("S fuscum") +
  theme_minimal()+
  theme(plot.title = element_text(hjust = 0.5, face = "italic", size = 11)) +
  xlab("") + 
  ylab("")+
  geom_smooth(method = "lm")+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13)) 

fig8g <- ggplot(s_maj, aes(fieldNotes, organismQuantity))+
  geom_point()+
  ggtitle("S majus") +
  theme_minimal()+
  theme(plot.title = element_text(hjust = 0.5, face = "italic", size = 11)) +
  xlab("") + 
  ylab("")+
  geom_smooth(method = "lm")+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13)) 

figure8 <- ggarrange(fig8a, fig8b, fig8c, fig8d, fig8e, fig8f, fig8g, fig8f, ncol = 2, nrow = 4)

annotate_figure(
  figure8,
  bottom = text_grob("Water level, cm below the surface", y= 1, hjust = 0.5, size = 15),
  left = text_grob("Annual growth increment, cm", x= 1, size = 15, rot = 90),
  right = text_grob("*Red line marks statistically significant correlation", hjust = 1, y=0.5, size = 13, rot = 90, color = "red")
)


# прирост между местообитаниями отличается?

t.test(organismQuantity ~ habitat, withoutexperiment) 
#t = 4.5085, df = 800.13, p-value = 7.506e-06

pairwise.wilcox.test(withoutexperiment$organismQuantity, withoutexperiment$habitat, 
                     paired = FALSE, exact=FALSE) #p-value = 1.6e-06                            

#визуализируем
ggplot(withoutexperiment, aes (x = organismQuantity, y = habitat))+
  geom_boxplot()+
  labs(x = "Growth increment, cm", y = "Habitats")+
  theme_minimal() 


# влияние OTC на прирост в целом и по годам
t.test(organismQuantity ~ occurrenceRemarks, withotc) #t = 1.2072, df = 355.17, p-value = 0.2282

year19 <- withotc[withotc$Year == 2019,]
t.test(organismQuantity ~ occurrenceRemarks, year19) #p-value = 0.912
year20 <- withotc[withotc$Year == 2020,]
t.test(organismQuantity ~ occurrenceRemarks, year20) #p-value = 0.2082
year21 <- withotc[withotc$Year == 2021,]
t.test(organismQuantity ~ occurrenceRemarks, year21) #p-value = 0.2169
year22 <- withotc[withotc$Year == 2022,]
t.test(organismQuantity ~ occurrenceRemarks, year22) #p-value = 0.3094


pairwise.wilcox.test(withotc$organismQuantity, withotc$experiment, 
                     paired = FALSE, exact=FALSE) #p = 0.043

pairwise.wilcox.test(year19$organismQuantity, year19$experiment, 
                     paired = FALSE, exact=FALSE) #p = 0.85
pairwise.wilcox.test(year20$organismQuantity, year20$experiment, 
                     paired = FALSE, exact=FALSE) #p = 0.29
pairwise.wilcox.test(year21$organismQuantity, year21$experiment, 
                     paired = FALSE, exact=FALSE) #p = 0.18
pairwise.wilcox.test(year22$organismQuantity, year22$experiment, 
                     paired = FALSE, exact=FALSE) #p = 0.39

#Рисунок 9. Диаграммы размаха (geom_boxplot, ggplot), демонстрирующие различия прироста сфагнума (S. balticum) в экспериментальных условиях (повышение температуры с помощью OTC) и в контроле.
ggplot(withotc, aes (x = organismQuantity, y = occurrenceRemarks, fill = Year))+
  geom_boxplot(alpha = 0.5)+
  scale_fill_brewer(palette="Spectral")+
  labs(x = "Growth increment, cm", y = "Experiment")+
  theme_minimal()+
  theme(legend.title=element_blank(), legend.position = c(0.8, 0.9))+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13)) +
  theme(axis.title.y = element_text(size = 15))+
  theme(axis.title.x = element_text(size = 15)) 


# какие параметры значимо влияют на первичную продукцию?
# Таблица 6. Результаты множественного дисперсионного анализа (aov, stats), показывающие значимое влияние нескольких параметров и их взаимодействия на продукцию сфагнума.

aov_musproduct <- aov(organismQuantity ~ scientificName * Year * occurrenceRemarks, data = musproduct)
summary(aov_musproduct)

#выводим результаты
Table6 <- write.csv(anova_summary(aov_musproduct, effect.size = "ges", detailed = FALSE, observed = NULL), file = "Table 6.csv")

#для надежности, проверим также непараметрическим аналогом дисперсионного анализа по Краселу-Уоллесу, везде достоверно
kruskal.test(organismQuantity ~ scientificName, data = musproduct) #Kruskal-Wallis chi-squared = 21.289, df = 7, p-value = 0.003365
kruskal.test(organismQuantity ~ Year, data = musproduct) #Kruskal-Wallis chi-squared = 24.64, df = 3, p-value = 1.836e-05

musproduct$Year <-  as.factor(musproduct$Year)

# визуализируем различия продукции между видами и по годам
# Рисунок 10. Диаграммы размаха (geom_boxplot, ggplot), демонстрирующие различия первичной продукции по видам сфагнума и по годам.
fig10a <- ggplot(musproduct, aes (x = organismQuantity, y = reorder(scientificName, organismQuantity, FUN = median)))+
  geom_boxplot(alpha = 0.5)+
  scale_fill_brewer(palette="Spectral")+
  labs(x = "", y = "Species")+
  scale_color_discrete(name="")+
  theme_minimal()+
  theme(axis.text.y = element_text(size = 15))+
  theme(axis.text.x = element_text(size = 15))+
  theme(axis.title.y = element_text(size = 15))+
  theme(legend.title=element_blank(), legend.position = c(0.8, 0.9))

fig10b <- ggplot(musproduct, aes (x = organismQuantity, y = Year))+
  geom_boxplot(alpha = 0.5)+
  scale_fill_brewer(palette="Spectral")+
  labs(x = "", y = "Years")+
  scale_color_discrete(name="")+
  theme_minimal()+
  theme(axis.text.y = element_text(size = 15))+
  theme(axis.text.x = element_text(size = 15))+
  theme(axis.title.y = element_text(size = 15))+
  theme(legend.title=element_blank(), legend.position = c(0.8, 0.9))

figure <- ggarrange(fig10a, fig10b, ncol = 2, nrow = 1)

annotate_figure(
  figure,
  bottom = text_grob("Annual Net Primary Production, g/dm^2", y= 1, hjust = 0.5, size = 16),
)

#===========
## СРАВНИВАЕМ ПОЛУЧЕННЫЕ ДАННЫЕ ПРИРОСТА С ЛИТЕРАТУРНЫМИ ДАННЫМИ

# импортируем базу литературных данных
sphg_lit_db <- read.delim2("~/lit_db.csv")

str(sphg_lit_db)

# визуализируем литературные данные ввиде диаграммы размаха с наложенными точечными данными
# Рисунок 11. Диаграммы размаха (geom_boxplot, ggplot), демонстрирующие различия прироста 15 видов сфагнума по литературным данным (оранжевый) и нашим измерениям (желтый). Оранжевые и желтые точки – исходные данные; диаграмма размаха включает среднее, межквартильный размах, мин и макс значения; черные точки – выбросы диаграммы размаха.

ggplot2::ggplot(sphg_lit_db, aes (x = species, y = LI..mm..y, fill = Our_data))+
  geom_boxplot()+
  coord_flip()+
  labs(x = "", y = "Growth increment, mm")+
  geom_jitter(color=ifelse(sphg_lit_db$Our_data == "This study", "#ffffbf", "#f8766d"), size=1, alpha=1)+
  scale_fill_brewer(palette="Spectral")+
  theme_minimal()+
  theme(legend.title=element_blank(), legend.position = c(0.85, 0.3))+
  theme(axis.text.y = element_text(size = 13))+
  theme(axis.text.x = element_text(size = 13)) +
  theme(axis.title.y = element_text(size = 13))+
  theme(axis.title.x = element_text(size = 15)) 

#сравниваем литературные данные и наши по видам сфагнума
sang<- sphg_lit_db[sphg_lit_db$species == "S. angustifolium",]
t.test(LI..mm..y ~ Our_data, sang) #t = -0.032842, df = 27.515, p-value = 0.974
pairwise.wilcox.test(sang$LI..mm..y, sang$Our_data, paired = FALSE, exact=FALSE) #p = 0.9

sbalt<- sphg_lit_db[sphg_lit_db$species == "S. balticum",]
t.test(LI..mm..y ~ Our_data, sbalt) #t = 2.8068, df = 6.0778, p-value = 0.03046
pairwise.wilcox.test(sbalt$LI..mm..y, sbalt$Our_data, paired = FALSE, exact=FALSE) #p = 0.034

scap<- sphg_lit_db[sphg_lit_db$species == "S. capillifolium",]
t.test(LI..mm..y ~ Our_data, scap) #t = 2.551, df = 12.864, p-value = 0.02431
pairwise.wilcox.test(scap$LI..mm..y, scap$Our_data, paired = FALSE, exact=FALSE) #p = 0.19

sfus<- sphg_lit_db[sphg_lit_db$species == "S. fuscum",]
t.test(LI..mm..y ~ Our_data, sfus) #t = -2.6798, df = 179.93, p-value = 0.00805
pairwise.wilcox.test(sfus$LI..mm..y, sfus$Our_data, paired = FALSE, exact=FALSE) #p = 0.00079 

smag<- sphg_lit_db[sphg_lit_db$species == "S. magellanicum",]
t.test(LI..mm..y ~ Our_data, smag) #t = 3.4532, df = 140.11, p-value = 0.000733
pairwise.wilcox.test(smag$LI..mm..y, smag$Our_data, paired = FALSE, exact=FALSE) #p = 0.0038

smaj<- sphg_lit_db[sphg_lit_db$species == "S. majus",]
t.test(LI..mm..y ~ Our_data, smaj) #t = -0.27119, df = 18.115, p-value = 0.7893
pairwise.wilcox.test(smaj$LI..mm..y, smaj$Our_data, paired = FALSE, exact=FALSE) #p = 0.52

spap<- sphg_lit_db[sphg_lit_db$species == "S. papillosum",]
t.test(LI..mm..y ~ Our_data, spap) #t = -1.2244, df = 25.147, p-value = 0.2321
pairwise.wilcox.test(spap$LI..mm..y, spap$Our_data, paired = FALSE, exact=FALSE) #p = 0.12

#===========
## Цитирование использованных пакетов в списке литературы

library(magrittr)
library(tidyverse)
library(stats)
library(ggplot2)
library(ggpubr)
library(rstatix)
library(ggcorrplot)
library(corrplot)
library(reshape)
library(purrr)

c("magrittr", "tidyverse", "stats", "ggplot2", "ggpubr", "rstatix", "ggcorrplot", "corrplot", "reshape", "purrr") %>%
  map(citation) %>%
  print(style = "text")

