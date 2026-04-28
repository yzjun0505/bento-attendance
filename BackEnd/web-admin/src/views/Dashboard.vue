<template>
  <div class="page-container fade-in-up">
    <div class="dashboard-header">
      <div>
        <h2 class="page-title">{{ greeting }}，{{ userStore.userInfo?.name || '管理员' }}</h2>
        <p class="page-subtitle">{{ todayStr }} · 数据看板实时概览</p>
      </div>
      <div class="clock-widget">
        {{ currentTimeStr }}
      </div>
    </div>

    <div class="top-cards-row">
      <div class="overview-card">
        <div class="card-header">
          <h3 class="card-title">今日考勤概览</h3>
        </div>
        <div class="overview-grid">
          <div class="overview-item green">
            <div class="overview-icon"><el-icon :size="24"><UserFilled /></el-icon></div>
            <div class="overview-info">
              <div class="overview-label">当前在岗</div>
              <div class="overview-value">{{ stats.currentOnline }}</div>
            </div>
          </div>
          <div class="overview-item blue">
            <div class="overview-icon"><el-icon :size="24"><User /></el-icon></div>
            <div class="overview-info">
              <div class="overview-label">今日出勤</div>
              <div class="overview-value">
                {{ stats.totalAttendance }}
                <span class="trend-badge" :class="stats.attendanceChangePercent >= 0 ? 'up' : 'down'">
                  {{ stats.attendanceChangePercent >= 0 ? '+' : '' }}{{ stats.attendanceChangePercent || 0 }}% 较昨日
                </span>
              </div>
            </div>
          </div>
          <div class="overview-item red">
            <div class="overview-icon"><el-icon :size="24"><Warning /></el-icon></div>
            <div class="overview-info">
              <div class="overview-label">迟到/未打卡</div>
              <div class="overview-value">{{ distribution.late + distribution.absent }}</div>
            </div>
          </div>
        </div>
      </div>

      <div class="todo-card">
        <div class="card-header">
          <h3 class="card-title">待审核申诉</h3>
          <el-button type="primary" link @click="$router.push('/notifications')">
            去审批 <el-icon class="ml-1"><ArrowRight /></el-icon>
          </el-button>
        </div>
        <div class="todo-list">
          <div v-for="todo in todos.slice(0, 3)" :key="todo.id" class="todo-item">
            <div class="todo-content">
              <div class="todo-user">{{ todo.userName }}</div>
              <div class="todo-desc">{{ todo.reason || todo.type }}</div>
            </div>
            <div class="todo-time">{{ formatTime(todo.created_at) }}</div>
          </div>
          <el-empty v-if="!todos.length" description="暂无待审核申诉" :image-size="40" style="padding: 10px 0"></el-empty>
        </div>
      </div>
    </div>

    <div class="charts-row">
      <div class="chart-card chart-left">
        <div class="chart-title">近7天项目部出勤趋势</div>
        <v-chart class="chart-instance" :option="trendOption" autoresize />
      </div>
      <div class="chart-card chart-right">
        <div class="chart-title">今日打卡状态分布</div>
        <v-chart class="chart-instance" :option="distributionOption" autoresize />
      </div>
    </div>

    <div class="anomaly-card">
      <div class="anomaly-header">
        <span class="anomaly-title">最新异常打卡预警</span>
        <span class="anomaly-refresh" @click="fetchAnomalies">刷新</span>
      </div>
      <el-table :data="anomalies" style="width: 100%" empty-text="暂无异常记录">
        <el-table-column prop="userName" label="姓名" width="120" />
        <el-table-column prop="projectName" label="项目部" min-width="160" />
        <el-table-column prop="anomalyType" label="异常类型" width="140">
          <template #default="{ row }">
            <el-tag :type="row.anomalyType === '围栏外打卡' ? 'danger' : 'warning'" size="small">
              {{ row.anomalyType }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="time" label="时间" width="200">
          <template #default="{ row }">
            {{ formatTime(row.time) }}
          </template>
        </el-table-column>
      </el-table>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { LineChart, PieChart } from 'echarts/charts'
import {
  TitleComponent,
  TooltipComponent,
  LegendComponent,
  GridComponent,
  GraphicComponent
} from 'echarts/components'
import VChart from 'vue-echarts'
import { useUserStore } from '@/store/user'
import { getDashboardStats, getDashboardTrend, getDashboardDistribution, getDashboardAnomalies, getDashboardTodos } from '@/api/dashboard'

use([CanvasRenderer, LineChart, PieChart, TitleComponent, TooltipComponent, LegendComponent, GridComponent, GraphicComponent])

const userStore = useUserStore()

const stats = reactive({
  totalAttendance: 0,
  currentOnline: 0,
  abnormalCount: 0,
  activeProjects: 0,
  attendanceChangePercent: 0
})

const trendData = ref([])
const distribution = reactive({ normal: 0, late: 0, leave: 0, absent: 0 })
const anomalies = ref([])
const todos = ref([])

const now = ref(new Date())
let clockTimer = null

const updateClock = () => {
  now.value = new Date()
}

const currentTimeStr = computed(() => {
  const d = now.value
  const pad = n => String(n).padStart(2, '0')
  return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
})

let refreshTimer = null

const greeting = computed(() => {
  const h = now.value.getHours()
  if (h < 6) return '凌晨好'
  if (h < 9) return '早上好'
  if (h < 12) return '上午好'
  if (h < 14) return '中午好'
  if (h < 18) return '下午好'
  return '晚上好'
})

const todayStr = computed(() => {
  const d = now.value
  const days = ['日', '一', '二', '三', '四', '五', '六']
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日 星期${days[d.getDay()]}`
})

const isDark = computed(() => document.documentElement.classList.contains('dark'))

const chartTextColor = computed(() => isDark.value ? '#8b92a5' : '#64748B')
const chartGridColor = computed(() => isDark.value ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.06)')

const projectColors = [
  '#3b82f6', '#10b981', '#f59e0b', '#8b5cf6', '#ef4444',
  '#06b6d4', '#ec4899', '#14b8a6', '#f97316', '#6366f1'
]

const trendOption = computed(() => {
  const projectMap = new Map()
  const dateSet = new Set()

  trendData.value.forEach(item => {
    dateSet.add(item.date)
    if (!projectMap.has(item.projectName)) {
      projectMap.set(item.projectName, {})
    }
    projectMap.get(item.projectName)[item.date] = { count: item.count, expectedCount: item.expectedCount || 0 }
  })

  const dates = [...dateSet].sort()
  const projectNames = [...projectMap.keys()]

  const series = []
  projectNames.forEach((name, idx) => {
    const color = projectColors[idx % projectColors.length]
    series.push({
      name: `${name} (实际)`,
      type: 'line',
      smooth: true,
      symbol: 'circle',
      symbolSize: 6,
      lineStyle: { width: 2, type: 'solid' },
      areaStyle: {
        opacity: 0.08
      },
      itemStyle: { color },
      data: dates.map(d => projectMap.get(name)[d]?.count || 0)
    })
    series.push({
      name: `${name} (应到)`,
      type: 'line',
      smooth: true,
      symbol: 'circle',
      symbolSize: 6,
      lineStyle: { width: 2, type: 'dashed' },
      itemStyle: { color },
      data: dates.map(d => projectMap.get(name)[d]?.expectedCount || 0)
    })
  })

  return {
    tooltip: {
      trigger: 'axis',
      backgroundColor: isDark.value ? 'rgba(28,30,46,0.9)' : 'rgba(255,255,255,0.95)',
      borderColor: isDark.value ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)',
      textStyle: { color: isDark.value ? '#f1f3f5' : '#1E293B' }
    },
    legend: {
      data: series.map(s => s.name),
      textStyle: { color: chartTextColor.value, fontSize: 12 },
      bottom: 0,
      icon: 'roundRect',
      itemWidth: 14,
      itemHeight: 8
    },
    grid: {
      left: '3%',
      right: '4%',
      top: '8%',
      bottom: '14%',
      containLabel: true
    },
    xAxis: {
      type: 'category',
      data: dates.map(d => d.slice(5)),
      boundaryGap: false,
      axisLine: { lineStyle: { color: chartGridColor.value } },
      axisLabel: { color: chartTextColor.value, fontSize: 11 },
      axisTick: { show: false }
    },
    yAxis: {
      type: 'value',
      minInterval: 1,
      axisLine: { show: false },
      axisTick: { show: false },
      splitLine: { lineStyle: { color: chartGridColor.value } },
      axisLabel: { color: chartTextColor.value, fontSize: 11 }
    },
    series
  }
})

const distributionOption = computed(() => {
  const total = distribution.normal + distribution.late + distribution.leave + distribution.absent

  return {
    tooltip: {
      trigger: 'item',
      backgroundColor: isDark.value ? 'rgba(28,30,46,0.9)' : 'rgba(255,255,255,0.95)',
      borderColor: isDark.value ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)',
      textStyle: { color: isDark.value ? '#f1f3f5' : '#1E293B' }
    },
    legend: {
      orient: 'horizontal',
      bottom: 0,
      textStyle: { color: chartTextColor.value, fontSize: 12 },
      icon: 'circle',
      itemWidth: 8,
      itemHeight: 8,
      itemGap: 16
    },
    graphic: [
      {
        type: 'text',
        left: 'center',
        top: '35%',
        style: {
          text: String(total),
          fontSize: 28,
          fontWeight: 700,
          fill: isDark.value ? '#f1f3f5' : '#1E293B',
          textAlign: 'center'
        }
      },
      {
        type: 'text',
        left: 'center',
        top: '48%',
        style: {
          text: '总人数',
          fontSize: 12,
          fill: chartTextColor.value,
          textAlign: 'center'
        }
      }
    ],
    series: [
      {
        type: 'pie',
        radius: ['50%', '72%'],
        center: ['50%', '42%'],
        avoidLabelOverlap: false,
        itemStyle: {
          borderRadius: 6,
          borderColor: isDark.value ? 'rgba(28,30,46,1)' : 'rgba(255,255,255,1)',
          borderWidth: 2
        },
        label: { show: false },
        emphasis: {
          label: { show: false },
          itemStyle: { shadowBlur: 10, shadowOffsetX: 0, shadowColor: 'rgba(0,0,0,0.2)' }
        },
        data: [
          { value: distribution.normal, name: '正常', itemStyle: { color: '#10b981' } },
          { value: distribution.late, name: '迟到', itemStyle: { color: '#f59e0b' } },
          { value: distribution.leave, name: '请假', itemStyle: { color: '#3b82f6' } },
          { value: distribution.absent, name: '未打卡', itemStyle: { color: '#ef4444' } }
        ]
      }
    ]
  }
})

function formatTime(time) {
  if (!time) return ''
  const d = new Date(time)
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
}

async function fetchStats() {
  try {
    const res = await getDashboardStats()
    Object.assign(stats, res.data)
  } catch (e) { /* ignore */ }
}

async function fetchTrend() {
  try {
    const res = await getDashboardTrend({ days: 7 })
    trendData.value = res.data || []
  } catch (e) { /* ignore */ }
}

async function fetchDistribution() {
  try {
    const res = await getDashboardDistribution()
    Object.assign(distribution, res.data)
  } catch (e) { /* ignore */ }
}

async function fetchAnomalies() {
  try {
    const res = await getDashboardAnomalies({ limit: 5 })
    anomalies.value = res.data || []
  } catch (e) { /* ignore */ }
}

async function fetchTodos() {
  try {
    const res = await getDashboardTodos()
    todos.value = res.data?.pendingAppeals || []
  } catch (e) { /* ignore */ }
}

async function fetchAll() {
  await Promise.all([fetchStats(), fetchTrend(), fetchDistribution(), fetchAnomalies(), fetchTodos()])
}

onMounted(() => {
  updateClock()
  clockTimer = window.setInterval(updateClock, 1000)
  fetchAll()
  refreshTimer = window.setInterval(fetchAll, 30000)
})

onUnmounted(() => {
  if (clockTimer) {
    window.clearInterval(clockTimer)
    clockTimer = null
  }
  if (refreshTimer) {
    window.clearInterval(refreshTimer)
    refreshTimer = null
  }
})
</script>

<style scoped>
.dashboard-header {
  background: var(--bg-card);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-lg);
  padding: 16px 24px;
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.2);
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.clock-widget {
  font-size: 32px;
  font-weight: 300;
  font-family: monospace, sans-serif;
  color: var(--text-secondary);
  letter-spacing: 2px;
}

.top-cards-row {
  display: grid;
  grid-template-columns: 3fr 2fr;
  gap: 20px;
}

.overview-card, .todo-card {
  background: var(--bg-card);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-lg);
  padding: 24px;
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.2);
  display: flex;
  flex-direction: column;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.card-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}

.overview-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
  flex: 1;
}

.overview-item {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-light);
}

.overview-item.green {
  background: rgba(16, 185, 129, 0.05);
}

.overview-item.blue {
  background: rgba(59, 130, 246, 0.05);
}

.overview-item.red {
  background: rgba(239, 68, 68, 0.05);
}

:root.dark .overview-item.green {
  background: rgba(16, 185, 129, 0.08);
}

:root.dark .overview-item.blue {
  background: rgba(59, 130, 246, 0.08);
}

:root.dark .overview-item.red {
  background: rgba(239, 68, 68, 0.08);
}

.overview-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.overview-item.blue .overview-icon { background: rgba(59, 130, 246, 0.12); color: var(--accent-blue); }
.overview-item.green .overview-icon { background: rgba(16, 185, 129, 0.12); color: var(--accent-green); }
.overview-item.red .overview-icon { background: rgba(239, 68, 68, 0.12); color: var(--accent-red, #ef4444); }

.overview-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.overview-label {
  font-size: 13px;
  color: var(--text-secondary);
}

.overview-value {
  font-size: 24px;
  font-weight: 700;
  color: var(--text-primary);
  display: flex;
  align-items: baseline;
  gap: 8px;
}

.trend-badge {
  font-size: 12px;
  padding: 2px 6px;
  border-radius: 4px;
  font-weight: 500;
}

.trend-badge.up {
  background: rgba(16, 185, 129, 0.1);
  color: var(--accent-green);
}

.trend-badge.down {
  background: rgba(239, 68, 68, 0.1);
  color: var(--accent-red, #ef4444);
}

.todo-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
  flex: 1;
  justify-content: center;
}

.todo-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  background: rgba(0, 0, 0, 0.02);
  border-radius: var(--radius-md);
  border: 1px solid var(--border-light);
  transition: var(--transition);
}

:root.dark .todo-item {
  background: rgba(255, 255, 255, 0.02);
}

.todo-item:hover {
  background: rgba(0, 0, 0, 0.04);
}

:root.dark .todo-item:hover {
  background: rgba(255, 255, 255, 0.04);
}

.todo-content {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.todo-user {
  font-size: 14px;
  font-weight: 500;
  color: var(--text-primary);
}

.todo-desc {
  font-size: 12px;
  color: var(--text-secondary);
}

.todo-time {
  font-size: 12px;
  color: var(--text-secondary);
}

.charts-row {
  display: flex;
  gap: 20px;
}

.chart-card {
  background: var(--bg-card);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-lg);
  padding: 24px;
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.2);
}

.chart-left {
  flex: 7;
  min-width: 0;
}

.chart-right {
  flex: 3;
  min-width: 0;
}

.chart-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 16px;
}

.chart-instance {
  width: 100%;
  height: 340px;
}

.anomaly-card {
  background: var(--bg-card);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-lg);
  padding: 24px;
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.2);
}

.anomaly-card :deep(.el-table),
.anomaly-card :deep(.el-table tr),
.anomaly-card :deep(.el-table th.el-table__cell),
.anomaly-card :deep(.el-table td.el-table__cell) {
  background-color: transparent;
}

.anomaly-card :deep(.el-table th.el-table__cell) {
  color: #888;
  border-bottom: 1px solid var(--border-light);
}

.anomaly-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.anomaly-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
}

.anomaly-refresh {
  font-size: 13px;
  color: var(--accent-blue);
  cursor: pointer;
  transition: var(--transition);
}

.anomaly-refresh:hover {
  opacity: 0.7;
}

@media (max-width: 1200px) {
  .top-cards-row {
    grid-template-columns: 1fr;
  }
  .charts-row {
    flex-direction: column;
  }
}

@media (max-width: 768px) {
  .overview-grid {
    grid-template-columns: 1fr;
  }
}
</style>
