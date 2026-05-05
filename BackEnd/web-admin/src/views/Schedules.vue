<template>
  <div class="page-container fade-in-up">
    <div class="unified-card">
      <div class="header-section">
        <div>
          <h2 class="page-title">排班管理</h2>
          <p class="page-subtitle">为员工分配每日班次</p>
        </div>
        <el-button type="primary" :icon="Plus" @click="batchDialogVisible = true">批量排班</el-button>
      </div>

      <div class="filter-section">
        <el-date-picker
          v-model="currentMonth"
          type="month"
          placeholder="选择月份"
          format="YYYY年MM月"
          value-format="YYYY-MM"
          @change="loadCalendarData"
          style="width: 160px"
        />
        <el-select v-model="selectedUsers" multiple collapse-tags placeholder="筛选人员" clearable style="width: 220px" @change="loadCalendarData">
          <el-option v-for="u in userList" :key="u.id" :label="u.name" :value="u.id" />
        </el-select>
      </div>

      <div class="table-section" style="padding: 20px;">
        <div v-loading="loading" style="flex: 1;">
          <!-- 日历网格 -->
        <div class="calendar-header">
          <div v-for="d in weekDays" :key="d" class="calendar-cell header-cell">{{ d }}</div>
        </div>
        <div class="calendar-body">
          <div
            v-for="(day, idx) in calendarDays"
            :key="idx"
            class="calendar-cell day-cell"
            :class="{
              'other-month': !day.isCurrentMonth,
              'today': day.isToday,
              'weekend': day.isWeekend
            }"
            @click="day.isCurrentMonth && showDayDetail(day)"
          >
            <div class="day-number">{{ day.date }}</div>
            <div v-if="day.schedules && day.schedules.length > 0" class="day-shifts">
              <div
                v-for="s in day.schedules.slice(0, 3)"
                :key="s.id"
                class="shift-tag"
                :style="{ background: s.color || '#3B82F6' }"
              >
                {{ s.shift_name || s.shiftName || '班次' }}
              </div>
              <div v-if="day.schedules.length > 3" class="shift-more">+{{ day.schedules.length - 3 }}</div>
            </div>
            <div v-else-if="day.isCurrentMonth && day.isRest" class="rest-tag">休</div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- 当天排班详情 -->
    <el-dialog v-model="dayDetailVisible" :title="dayDetailTitle" width="460px">
      <div v-if="daySchedules.length === 0" style="text-align:center;color:var(--text-secondary);padding:20px">
        暂无排班安排
      </div>
      <div v-else>
        <div v-for="s in daySchedules" :key="s.id" style="display:flex;align-items:center;justify-content:space-between;padding:10px 0;border-bottom:1px solid var(--border-light)">
          <div style="display:flex;align-items:center;gap:8px">
            <span :style="{ width:'10px',height:'10px',borderRadius:'50%',background:s.color||'#3B82F6',display:'inline-block' }" />
            <span>{{ s.user_name || '—' }} · {{ s.shift_name || s.shiftName || '—' }}</span>
          </div>
          <el-button type="danger" text size="small" @click="handleDeleteSchedule(s)">移除</el-button>
        </div>
      </div>
      <template #footer>
        <el-button @click="dayDetailVisible = false">关闭</el-button>
      </template>
    </el-dialog>

    <!-- 批量排班弹窗 -->
    <el-dialog v-model="batchDialogVisible" title="批量排班" width="520px" :close-on-click-modal="false">
      <el-form ref="batchFormRef" :model="batchForm" :rules="batchRules" label-width="90px">
        <el-form-item label="选择人员" prop="user_ids">
          <el-select v-model="batchForm.user_ids" multiple placeholder="选择人员" style="width: 100%">
            <el-option v-for="u in userList" :key="u.id" :label="u.name" :value="u.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="日期范围" prop="date_range">
          <el-date-picker
            v-model="batchForm.date_range"
            type="daterange"
            range-separator="至"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            value-format="YYYY-MM-DD"
            style="width: 100%"
          />
        </el-form-item>
        <el-form-item label="选择班次" prop="shift_id">
          <el-select v-model="batchForm.shift_id" placeholder="选择班次" style="width: 100%">
            <el-option v-for="s in shiftList" :key="s.id" :label="s.name" :value="s.id">
              <span :style="{ display:'inline-block',width:'10px',height:'10px',borderRadius:'50%',background:s.color||'#3B82F6',marginRight:'8px' }" />
              {{ s.name }} ({{ formatTime(s.start_time) }}-{{ formatTime(s.end_time) }})
            </el-option>
          </el-select>
        </el-form-item>
        <el-form-item label="跳过节假日">
          <el-switch v-model="batchForm.skip_holidays" />
          <span style="margin-left:8px;font-size:12px;color:var(--text-secondary)">自动跳过节假日和周末</span>
        </el-form-item>
        <el-form-item label="周末休息">
          <el-switch v-model="batchForm.weekend_rest" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="batchDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="batchSaving" @click="handleBatchSchedule">确定排班</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { getSchedules, batchSchedule, deleteSchedule } from '@/api/schedules'
import { getShifts } from '@/api/shifts'
import { getUsers } from '@/api/users'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus } from '@element-plus/icons-vue'

const weekDays = ['日', '一', '二', '三', '四', '五', '六']
const loading = ref(false)
const batchSaving = ref(false)
const userList = ref([])
const shiftList = ref([])
const scheduleMap = ref({}) // { 'YYYY-MM-DD': [schedule items] }
const selectedUsers = ref([])
const currentMonth = ref(new Date().toISOString().slice(0, 7))

const dayDetailVisible = ref(false)
const dayDetailTitle = ref('')
const daySchedules = ref([])

const batchDialogVisible = ref(false)
const batchFormRef = ref(null)
const batchForm = reactive({
  user_ids: [],
  date_range: [],
  shift_id: null,
  skip_holidays: true,
  weekend_rest: true
})
const batchRules = {
  user_ids: [{ required: true, message: '请选择人员', trigger: 'change' }],
  date_range: [{ required: true, message: '请选择日期范围', trigger: 'change' }],
  shift_id: [{ required: true, message: '请选择班次', trigger: 'change' }]
}

const calendarDays = computed(() => {
  const [year, month] = currentMonth.value.split('-').map(Number)
  const firstDay = new Date(year, month - 1, 1)
  const lastDay = new Date(year, month, 0)
  const days = []
  const today = new Date()
  const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`

  // 补齐月初之前的空白
  const startWeekday = firstDay.getDay()
  for (let i = startWeekday - 1; i >= 0; i--) {
    const d = new Date(year, month - 1, -i)
    days.push({ date: d.getDate(), isCurrentMonth: false, isToday: false, isWeekend: d.getDay() === 0 || d.getDay() === 6 })
  }

  // 当月天数
  for (let d = 1; d <= lastDay.getDate(); d++) {
    const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(d).padStart(2, '0')}`
    const dt = new Date(year, month - 1, d)
    const isWeekend = dt.getDay() === 0 || dt.getDay() === 6
    const schedules = scheduleMap.value[dateStr] || []
    const isRest = schedules.some(s => s.is_rest === 1 || s.isRest)
    days.push({
      date: d,
      dateStr,
      isCurrentMonth: true,
      isToday: dateStr === todayStr,
      isWeekend,
      isRest,
      schedules
    })
  }

  // 补齐月末之后
  const remaining = 42 - days.length
  for (let i = 1; i <= remaining; i++) {
    const d = new Date(year, month, i)
    days.push({ date: i, isCurrentMonth: false, isToday: false, isWeekend: d.getDay() === 0 || d.getDay() === 6 })
  }

  return days
})

onMounted(() => {
  loadUsers()
  loadShifts()
  loadCalendarData()
})

async function loadUsers() {
  try {
    const res = await getUsers({ pageSize: 999, status: 1 })
    userList.value = res.data.list || []
  } catch (e) {
    console.warn('加载用户列表失败:', e)
  }
}

async function loadShifts() {
  try {
    const res = await getShifts({ pageSize: 999 })
    shiftList.value = res.data.list || res.data || []
  } catch (e) {
    console.warn('加载班次列表失败:', e)
  }
}

async function loadCalendarData() {
  loading.value = true
  try {
    const params = { month: currentMonth.value }
    if (selectedUsers.value.length > 0) params.user_ids = selectedUsers.value.join(',')
    const res = await getSchedules(params)
    const list = res.data.list || res.data || []
    const map = {}
    for (const item of list) {
      const dateKey = item.date || item.schedule_date
      if (!dateKey) continue
      if (!map[dateKey]) map[dateKey] = []
      map[dateKey].push(item)
    }
    scheduleMap.value = map
  } catch (e) {
    console.error('加载排班数据失败:', e)
  } finally {
    loading.value = false
  }
}

function showDayDetail(day) {
  if (!day.dateStr) return
  dayDetailTitle.value = `${day.dateStr} 排班详情`
  daySchedules.value = day.schedules || []
  dayDetailVisible.value = true
}

async function handleDeleteSchedule(item) {
  await ElMessageBox.confirm('确定移除此排班？', '警告', { type: 'warning' })
  try {
    await deleteSchedule(item.id)
    ElMessage.success('已移除')
    loadCalendarData()
    dayDetailVisible.value = false
  } catch (e) {
    ElMessage.error('移除失败')
  }
}

async function handleBatchSchedule() {
  const valid = await batchFormRef.value?.validate().catch(() => false)
  if (!valid) return
  batchSaving.value = true
  try {
    await batchSchedule({
      user_ids: batchForm.user_ids,
      start_date: batchForm.date_range[0],
      end_date: batchForm.date_range[1],
      shift_id: batchForm.shift_id,
      skip_holidays: batchForm.skip_holidays,
      weekend_rest: batchForm.weekend_rest
    })
    ElMessage.success('批量排班成功')
    batchDialogVisible.value = false
    loadCalendarData()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '排班失败')
  } finally {
    batchSaving.value = false
  }
}

function formatTime(val) {
  if (!val) return '--:--'
  const parts = String(val).split(':')
  return parts.length >= 2 ? `${parts[0]}:${parts[1]}` : val
}
</script>

<style scoped>
.calendar-header {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 1px;
  margin-bottom: 4px;
}
.header-cell {
  text-align: center;
  font-size: 13px;
  font-weight: 600;
  color: var(--text-secondary);
  padding: 8px 0;
}
.calendar-body {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 1px;
}
.calendar-cell {
  min-height: 90px;
  padding: 6px;
  border: 1px solid var(--border-light);
  border-radius: 6px;
  cursor: pointer;
  transition: background 0.2s;
}
.calendar-cell:hover {
  background: rgba(59, 130, 246, 0.05);
}
.day-cell.other-month {
  opacity: 0.3;
}
.day-cell.today {
  border-color: var(--accent-blue, #3B82F6);
  background: rgba(59, 130, 246, 0.05);
}
.day-cell.weekend .day-number {
  color: var(--accent-orange, #F59E0B);
}
.day-number {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 4px;
}
.day-shifts {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.shift-tag {
  font-size: 10px;
  color: #fff;
  padding: 1px 6px;
  border-radius: 3px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.shift-more {
  font-size: 10px;
  color: var(--text-secondary);
  text-align: center;
}
.rest-tag {
  display: inline-block;
  font-size: 11px;
  color: var(--accent-orange, #F59E0B);
  background: rgba(245, 158, 11, 0.1);
  padding: 1px 8px;
  border-radius: 3px;
  margin-top: 4px;
}
</style>
