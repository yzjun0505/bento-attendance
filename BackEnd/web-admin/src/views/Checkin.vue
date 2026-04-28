<template>
  <div class="page-container fade-in-up">
    <div class="unified-card">
      <div class="header-section">
        <div>
          <h2 class="page-title">打卡记录</h2>
          <p class="page-subtitle">查看所有人员的打卡明细</p>
        </div>
      </div>

      <div class="filter-section">
        <el-date-picker
          v-model="dateRange"
          type="daterange"
          range-separator="至"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
          format="YYYY-MM-DD"
          value-format="YYYY-MM-DD"
          style="width: 280px"
          @change="loadData"
        />
        <el-select v-model="filters.project_id" placeholder="项目" clearable style="width: 180px" @change="loadData">
          <el-option v-for="p in projectList" :key="p.id" :label="p.name" :value="p.id" />
        </el-select>
        <el-select v-model="filters.type" placeholder="打卡类型" clearable style="width: 130px" @change="loadData">
          <el-option label="上班打卡" value="clock_in" />
          <el-option label="下班打卡" value="clock_out" />
          <el-option label="实地考察" value="site_visit" />
          <el-option label="项目进度" value="progress" />
          <el-option label="安全检查" value="safety" />
        </el-select>
        <el-select v-model="filters.is_outside" placeholder="围栏状态" clearable style="width: 130px" @change="loadData">
          <el-option label="正常" :value="0" />
          <el-option label="围栏外" :value="1" />
        </el-select>
        <el-button type="primary" :icon="Search" @click="loadData">查询</el-button>
        <el-button plain :icon="Download" @click="handleExport">导出 Excel</el-button>
        
        <div class="segmented-control">
          <div class="segment-item" :class="{ active: viewMode === 'list' }" @click="viewMode = 'list'">
            <el-icon><List /></el-icon> 列表
          </div>
          <div class="segment-item" :class="{ active: viewMode === 'grid' }" @click="viewMode = 'grid'">
            <el-icon><Grid /></el-icon> 大图
          </div>
        </div>
      </div>

      <div class="table-section">
        <el-table
          v-show="viewMode === 'list'"
          :data="tableData"
          v-loading="loading"
          class="custom-table"
          style="width: 100%"
        >
          <el-table-column prop="user_name" label="姓名" min-width="100">
            <template #default="{ row }">
              <div style="display: flex; align-items: center; gap: 8px;">
                <el-avatar :size="28" style="background: var(--gradient-green); font-size: 12px; flex-shrink: 0;">
                  {{ row.user_name ? row.user_name.charAt(0) : '—' }}
                </el-avatar>
                <span>{{ row.user_name || '—' }}</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column prop="project_name" label="所属项目" min-width="120">
            <template #default="{ row }">{{ row.project_name || '—' }}</template>
          </el-table-column>
          <el-table-column prop="type" label="打卡类型" width="110">
            <template #default="{ row }">
                <el-tag 
                :type="getTypeTagColor(row.type)" 
                size="small" 
                round 
                effect="dark"
              >
                {{ getTypeName(row.type) }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="photo" label="打卡照片" width="100">
            <template #default="{ row }">
              <div v-if="row.photo" class="photo-cell" @click="showPhoto(row.photo)">
                <el-image
                  :src="getPhotoUrl(row.photo)"
                  fit="cover"
                  class="photo-thumb"
                >
                  <template #error>
                    <div class="photo-error">
                      <el-icon><Picture /></el-icon>
                    </div>
                  </template>
                </el-image>
              </div>
              <span v-else style="color: #999; font-size: 12px;">—</span>
            </template>
          </el-table-column>
          <el-table-column prop="anti_fake_code" label="防伪码" width="160">
            <template #default="{ row }">
              <el-link
                v-if="row.anti_fake_code"
                type="primary"
                :underline="false"
                class="code-link"
                @click="goToAntiFakeQuery(row.anti_fake_code)"
              >
                <el-icon><Ticket /></el-icon>
                {{ row.anti_fake_code }}
              </el-link>
              <span v-else style="color: #999; font-size: 12px;">—</span>
            </template>
          </el-table-column>
          <el-table-column prop="address" label="打卡地点" min-width="180" show-overflow-tooltip>
            <template #default="{ row }">{{ row.address || '—' }}</template>
          </el-table-column>
          <el-table-column prop="is_outside" label="围栏" width="90">
            <template #default="{ row }">
              <el-tag v-if="row.is_outside" type="danger" size="small" round effect="dark">围栏外</el-tag>
              <el-tag v-else type="success" size="small" round effect="dark">正常</el-tag>
              <div style="font-size: 12px; color: #999; margin-top: 4px;" v-if="row.distance_to_fence != null">
                距离中心: {{ Math.round(row.distance_to_fence) }}米
              </div>
            </template>
          </el-table-column>
          <el-table-column prop="created_at" label="打卡时间" width="180">
            <template #default="{ row }">
              <div>{{ formatTime(row.created_at) }}</div>
              <div v-if="row.expected_time" style="font-size: 12px; color: #999; margin-top: 4px;">
                规定时间: {{ row.expected_time }}
              </div>
              <div style="margin-top: 4px;" v-if="row.attendance_status === 'late' || row.attendance_status === 'early'">
                <el-tag v-if="row.attendance_status === 'late'" type="danger" size="small" effect="plain">迟到</el-tag>
                <el-tag v-if="row.attendance_status === 'early'" type="danger" size="small" effect="plain">早退</el-tag>
              </div>
            </template>
          </el-table-column>
          <el-table-column prop="remark" label="备注" min-width="120" show-overflow-tooltip>
            <template #default="{ row }">{{ row.remark || '—' }}</template>
          </el-table-column>
        </el-table>

        <!-- 图库视图 -->
        <div v-show="viewMode === 'grid'" class="grid-card-container" v-loading="loading">
          <div v-if="tableData.length === 0 && !loading" class="empty-state">暂无打卡数据</div>
          <div class="photo-grid" v-else>
            <div v-for="row in tableData" :key="row.id" class="photo-card">
              <div class="photo-wrapper">
                <el-image
                  v-if="row.photo"
                  :src="getPhotoUrl(row.photo)"
                  fit="cover"
                  class="card-image"
                  lazy
                  @click="showPhoto(row.photo)"
                >
                  <template #error>
                    <div class="no-photo"><el-icon><Picture /></el-icon></div>
                  </template>
                </el-image>
                <div v-else class="no-photo"><el-icon><Picture /></el-icon></div>
                <div class="status-tag">
                  <el-tag :type="getTypeTagColor(row.type)" size="small" effect="dark" round>
                    {{ getTypeName(row.type) }}
                  </el-tag>
                </div>
              </div>
              <div class="card-info">
                <div class="info-header">
                  <span class="user-name">
                    <el-avatar :size="20" style="background: var(--gradient-green); font-size: 10px; margin-right: 4px; vertical-align: middle;">
                      {{ row.user_name ? row.user_name.charAt(0) : '—' }}
                    </el-avatar>
                    {{ row.user_name || '—' }}
                  </span>
                  <span class="time">{{ formatTime(row.created_at) }}</span>
                </div>
                <div v-if="row.expected_time" style="font-size: 12px; color: #999; margin-top: 4px; margin-bottom: 4px;">
                  规定时间: {{ row.expected_time }}
                  <el-tag v-if="row.attendance_status === 'late'" type="danger" size="small" effect="plain" style="margin-left: 4px;">迟到</el-tag>
                  <el-tag v-if="row.attendance_status === 'early'" type="danger" size="small" effect="plain" style="margin-left: 4px;">早退</el-tag>
                </div>
                <div class="info-project">{{ row.project_name || '—' }}</div>
                <div class="info-address"><el-icon><Location /></el-icon> {{ row.address || '—' }}</div>
                <div class="info-distance" v-if="row.distance_to_fence != null" style="font-size: 12px; color: #999; margin-top: 4px;">
                  距离中心: {{ Math.round(row.distance_to_fence) }}米
                  <el-tag v-if="row.is_outside" type="danger" size="small" style="margin-left: 4px;">围栏外</el-tag>
                </div>
                <div class="info-code" v-if="row.anti_fake_code">
                  <el-link type="primary" :underline="false" class="code-link" @click.stop="goToAntiFakeQuery(row.anti_fake_code)">
                    <el-icon><Ticket /></el-icon> {{ row.anti_fake_code }}
                  </el-link>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div style="padding: 16px; display: flex; justify-content: flex-end; border-top: 1px solid var(--border-light);">
          <el-pagination
            v-model:current-page="pagination.page"
            v-model:page-size="pagination.pageSize"
            :total="pagination.total"
            :page-sizes="[10, 20, 50]"
            layout="total, sizes, prev, pager, next"
            background
            @size-change="loadData"
            @current-change="loadData"
          />
        </div>
      </div>
    </div>

    <el-dialog
      v-model="photoDialogVisible"
      title="打卡照片"
      width="800px"
      destroy-on-close
    >
      <div class="photo-dialog-content" style="text-align: center;">
        <img
          :src="currentPhotoUrl"
          alt="打卡大图"
          style="max-width: 100%; max-height: 70vh; object-fit: contain; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);"
        />
      </div>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { getCheckins, exportCheckins } from '@/api/checkin'
import { getAllProjects } from '@/api/projects'
import { Search, Picture, List, Grid, Location, Download, Ticket } from '@element-plus/icons-vue'

const router = useRouter()

const loading = ref(false)
const tableData = ref([])
const projectList = ref([])
const dateRange = ref(null)
const filters = reactive({ project_id: '', type: '', is_outside: '' })
const pagination = reactive({ page: 1, pageSize: 20, total: 0 })
const photoDialogVisible = ref(false)
const currentPhotoUrl = ref('')
const viewMode = ref('list')

const TYPE_NAME_MAP = {
  'in': '上班',
  'out': '下班',
  'clock_in': '上班',
  'clock_out': '下班',
  'site_visit': '实地考察',
  'progress': '项目进度',
  'safety': '安全检查',
  'device': '设备位置',
  'custom': '自定义',
}

function getTypeName(type) {
  return TYPE_NAME_MAP[type] || type
}

function getTypeTagColor(type) {
  if (type === 'in' || type === 'clock_in') return 'success'
  if (type === 'out' || type === 'clock_out') return 'info'
  return 'warning'
}

onMounted(() => {
  loadData()
  loadProjects()
})

async function loadData() {
  loading.value = true
  try {
    const params = {
      ...filters,
      page: pagination.page,
      pageSize: pagination.pageSize
    }
    if (dateRange.value && dateRange.value.length === 2) {
      params.date_start = dateRange.value[0] + ' 00:00:00'
      params.date_end = dateRange.value[1] + ' 23:59:59'
    }
    const res = await getCheckins(params)
    tableData.value = res.data.list
    pagination.total = res.data.total
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '加载打卡记录失败')
  } finally {
    loading.value = false
  }
}

async function loadProjects() {
  try {
    const res = await getAllProjects()
    projectList.value = res.data
  } catch (e) {
    console.warn('加载项目列表失败:', e)
  }
}

function formatTime(t) {
  if (!t) return '—'
  // Ensure that if the time string comes without timezone info (e.g., from DB raw string), it's treated as UTC
  let timeStr = t;
  if (typeof t === 'string' && !t.includes('T') && !t.includes('Z')) {
    timeStr = t.replace(' ', 'T') + 'Z';
  }
  return new Date(timeStr).toLocaleString('zh-CN', {
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit'
  })
}

function getPhotoUrl(photo) {
  if (!photo) return ''
  if (photo.startsWith('http')) return photo
  const baseUrl = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000'
  return baseUrl + photo
}

function showPhoto(photo) {
  currentPhotoUrl.value = getPhotoUrl(photo)
  photoDialogVisible.value = true
}

function goToAntiFakeQuery(code) {
  router.push({ name: 'AntiFakeQuery', query: { code } })
}

async function handleExport() {
  const params = {
    ...filters
  }
  if (dateRange.value && dateRange.value.length === 2) {
    params.date_start = dateRange.value[0] + ' 00:00:00'
    params.date_end = dateRange.value[1] + ' 23:59:59'
  }
  try {
    const res = await exportCheckins(params)
    const blob = new Blob([res], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' })
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `打卡记录_${new Date().toISOString().slice(0, 10)}.xlsx`
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)
  } catch (e) {
    console.error('导出失败', e)
  }
}
</script>

<style scoped>
.unified-card {
  background: var(--bg-card);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-lg);
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.2);
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow: hidden;
}

.header-section {
  padding: 24px 32px 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.filter-section {
  padding: 20px 32px;
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  align-items: center;
}

.table-section {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  padding: 0;
}

.table-section :deep(.el-table) {
  flex: 1;
}

/* 移除表格表头背景 */
.table-section :deep(.el-table th.el-table__cell) {
  background-color: transparent !important;
}

/* 分段控制器 */
.segmented-control {
  display: flex;
  background: var(--border-light);
  padding: 4px;
  border-radius: 8px;
  gap: 4px;
  margin-left: auto;
}

.segment-item {
  padding: 6px 16px;
  border-radius: 6px;
  font-size: 13px;
  color: var(--text-secondary);
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 6px;
  transition: all 0.3s;
}

.segment-item.active {
  background: var(--bg-card);
  color: var(--text-primary);
  box-shadow: 0 2px 8px rgba(0,0,0,0.08);
  font-weight: 500;
}

.photo-cell {
  cursor: pointer;
  display: inline-block;
  overflow: hidden;
  border-radius: 6px;
}

.photo-thumb {
  width: 48px;
  height: 48px;
  border-radius: 6px;
  border: 1px solid var(--border-light);
  transition: transform 0.3s ease, border-color 0.3s ease;
}

.photo-thumb:hover {
  transform: scale(1.15);
  border-color: var(--accent-blue);
}

.photo-error {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f5f7fa;
  color: #c0c4cc;
}

.photo-dialog-content {
  display: flex;
  justify-content: center;
  align-items: center;
}

.photo-error-large {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 300px;
  color: #c0c4cc;
}

.photo-error-large p {
  margin-top: 12px;
  font-size: 14px;
}

/* Photo Grid Styles */
.grid-card-container {
  padding: 16px 32px;
  overflow-y: auto;
  flex: 1;
}
.empty-state {
  text-align: center;
  padding: 40px;
  color: var(--text-muted);
}
.photo-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 20px;
}
.photo-card {
  background: var(--bg-card);
  border: 1px solid var(--border-light);
  border-radius: 12px;
  overflow: hidden;
  transition: transform 0.2s, box-shadow 0.2s;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}
.photo-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
  border-color: rgba(79, 140, 255, 0.3);
}
.photo-wrapper {
  position: relative;
  width: 100%;
  aspect-ratio: 3 / 4;
  background: #111218;
  overflow: hidden;
}
.card-image {
  width: 100%;
  height: 100%;
  transition: transform 0.4s ease;
}
.photo-card:hover .card-image {
  transform: scale(1.08);
}
.no-photo {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: rgba(255, 255, 255, 0.2);
  font-size: 32px;
  background: #1e1e24;
}
.status-tag {
  position: absolute;
  top: 10px;
  right: 10px;
  z-index: 2;
}
.card-info {
  padding: 14px;
}
.info-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}
.user-name {
  font-weight: 600;
  font-size: 14px;
  color: var(--text-primary);
  display: flex;
  align-items: center;
}
.time {
  font-size: 12px;
  color: var(--text-secondary);
}
.info-project, .info-address {
  font-size: 12px;
  color: var(--text-secondary);
  line-height: 1.5;
  margin-top: 4px;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  text-overflow: ellipsis;
}
.info-address {
  color: var(--text-muted);
}

.info-code {
  margin-top: 6px;
  font-size: 12px;
}

.code-link {
  font-family: 'Courier New', monospace;
  letter-spacing: 1px;
  font-size: 13px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
</style>
