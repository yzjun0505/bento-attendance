<template>
  <div v-if="result" class="ai-result">
    <div v-if="result.cards?.length" class="ai-cards">
      <div v-for="card in result.cards" :key="card.label" class="ai-card">
        <span>{{ card.label }}</span>
        <strong>{{ card.value }}</strong>
      </div>
    </div>

    <div v-if="chartRows.length" class="ai-mini-chart">
      <div v-for="row in chartRows" :key="row.name" class="ai-mini-row">
        <span class="ai-mini-name">{{ row.name }}</span>
        <div class="ai-mini-bar-track">
          <div class="ai-mini-bar" :style="{ width: `${row.percent}%` }"></div>
        </div>
        <span class="ai-mini-value">{{ row.value }}</span>
      </div>
    </div>

    <el-table
      v-if="result.rows?.length"
      :data="result.rows"
      class="ai-table"
      size="small"
      max-height="220"
    >
      <el-table-column
        v-for="col in visibleColumns"
        :key="col.prop"
        :prop="col.prop"
        :label="col.label"
        min-width="110"
        show-overflow-tooltip
      >
        <template #default="{ row }">
          <span v-if="col.prop === 'is_outside'">{{ row[col.prop] ? '是' : '否' }}</span>
          <span v-else>{{ row[col.prop] ?? '-' }}</span>
        </template>
      </el-table-column>
    </el-table>

    <div v-if="result.action" class="ai-action">
      <div class="ai-action-title">
        <el-icon><Warning /></el-icon>
        <span>{{ result.action.title }}</span>
      </div>
      <dl>
        <template v-for="field in actionFields" :key="field.label">
          <dt>{{ field.label }}</dt>
          <dd>{{ field.value }}</dd>
        </template>
      </dl>
      <el-button
        type="primary"
        size="small"
        :loading="confirming"
        @click="$emit('confirm-action', result.action)"
      >
        确认执行
      </el-button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  result: {
    type: Object,
    default: null
  },
  confirming: {
    type: Boolean,
    default: false
  }
})

defineEmits(['confirm-action'])

const visibleColumns = computed(() => {
  const cols = props.result?.columns || []
  return cols.slice(0, 5)
})

const chartRows = computed(() => {
  const chart = props.result?.chart
  if (!chart?.xAxis?.length || !chart?.series?.[0]?.data?.length) return []
  const values = chart.series[0].data.map(Number)
  const max = Math.max(...values, 1)
  return chart.xAxis.slice(0, 8).map((name, index) => {
    const value = values[index] || 0
    return {
      name,
      value,
      percent: Math.max(6, Math.round((value / max) * 100))
    }
  })
})

const fieldLabelMap = {
  title: '标题',
  content: '内容',
  target: '发送范围',
  userName: '员工',
  date: '日期',
  shiftName: '班次',
  name: '项目名称',
  address: '项目地址',
  radius: '围栏半径',
  description: '备注',
}

const targetMap = {
  visible_active_users: '当前权限内所有在职员工',
  user: '指定员工',
}

const actionFields = computed(() => {
  const payload = props.result?.action?.payload || {}
  return Object.entries(payload)
    .filter(([key, value]) => value !== null && value !== undefined && value !== '' && key !== 'userId' && key !== 'shiftId')
    .map(([key, value]) => ({
      label: fieldLabelMap[key] || key,
      value: key === 'target'
        ? (targetMap[value] || value)
        : (typeof value === 'object' ? JSON.stringify(value) : value)
    }))
})
</script>

<style scoped>
.ai-result {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-top: 10px;
}

.ai-cards {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}

.ai-card {
  border: 1px solid var(--border-color);
  background: rgba(255, 255, 255, 0.04);
  border-radius: 8px;
  padding: 10px;
  min-width: 0;
}

.ai-card span {
  display: block;
  color: var(--text-secondary);
  font-size: 12px;
}

.ai-card strong {
  display: block;
  color: var(--text-primary);
  font-size: 18px;
  margin-top: 4px;
  word-break: break-word;
}

.ai-mini-chart {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.ai-mini-row {
  display: grid;
  grid-template-columns: 84px 1fr 44px;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  color: var(--text-secondary);
}

.ai-mini-name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ai-mini-bar-track {
  height: 8px;
  border-radius: 999px;
  background: rgba(148, 163, 184, 0.18);
  overflow: hidden;
}

.ai-mini-bar {
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(90deg, #3b82f6, #10b981);
}

.ai-mini-value {
  text-align: right;
  color: var(--text-primary);
}

.ai-table {
  border-radius: 8px;
  overflow: hidden;
}

.ai-action {
  border: 1px solid rgba(245, 158, 11, 0.35);
  background: rgba(245, 158, 11, 0.08);
  border-radius: 8px;
  padding: 10px;
}

.ai-action-title {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--accent-orange);
  font-size: 13px;
  font-weight: 600;
}

.ai-action dl {
  display: grid;
  grid-template-columns: 72px 1fr;
  gap: 6px 10px;
  margin: 10px 0;
  font-size: 12px;
}

.ai-action dt {
  color: var(--text-muted);
}

.ai-action dd {
  margin: 0;
  color: var(--text-secondary);
  word-break: break-word;
}
</style>
