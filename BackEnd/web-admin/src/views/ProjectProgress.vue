<template>
  <div class="page-container fade-in-up">
    <div class="unified-card">
      <div class="header-section">
        <div>
          <h2 class="page-title">项目进度</h2>
          <p class="page-subtitle">查看节点进度、现场上报和验收状态</p>
        </div>
        <div class="header-actions">
          <el-input
            v-model="keyword"
            placeholder="搜索项目"
            :prefix-icon="Search"
            clearable
            style="width: 240px"
          />
          <el-button type="primary" :icon="Refresh" :loading="loading" @click="loadProjects">刷新</el-button>
        </div>
      </div>
    </div>

    <div class="progress-layout">
      <div class="project-list-panel">
        <div
          v-for="project in filteredProjects"
          :key="project.id"
          class="progress-project-card"
          :class="{ active: activeProject?.id === project.id }"
          @click="selectProject(project)"
        >
          <div class="project-card-title">
            <div>
              <h3>{{ project.name }}</h3>
              <p>{{ project.address || '未设置地址' }}</p>
            </div>
            <el-progress
              type="circle"
              :width="54"
              :stroke-width="6"
              :percentage="project.overallProgress || 0"
            />
          </div>
          <div class="project-stat-row">
            <span>节点 {{ project.totalNodes || 0 }}</span>
            <span>完成 {{ project.completedNodes || 0 }}</span>
            <span class="warning">待验收 {{ project.pendingReviewNodes || 0 }}</span>
            <span class="danger">逾期 {{ project.overdueNodes || 0 }}</span>
          </div>
          <div class="project-meta">
            最近上报：{{ formatDateTime(project.lastReportTime) || '暂无' }}
          </div>
        </div>

        <el-empty v-if="filteredProjects.length === 0 && !loading" description="暂无可访问项目" />
      </div>

      <div class="detail-panel">
        <template v-if="activeProject">
          <div class="detail-header">
            <div>
              <h3>{{ activeProject.name }}</h3>
              <p>{{ activeProject.address || '未设置地址' }}</p>
            </div>
            <el-button type="primary" :icon="Plus" @click="openNodeDialog()">创建节点</el-button>
          </div>

          <div class="summary-grid">
            <div class="summary-item">
              <span>整体进度</span>
              <strong>{{ summary.overallProgress || 0 }}%</strong>
            </div>
            <div class="summary-item">
              <span>待验收</span>
              <strong>{{ summary.pendingReviewNodes || 0 }}</strong>
            </div>
            <div class="summary-item">
              <span>进行中</span>
              <strong>{{ summary.inProgressNodes || 0 }}</strong>
            </div>
            <div class="summary-item">
              <span>最近上报</span>
              <strong>{{ recentReports.length }}</strong>
            </div>
          </div>

          <div class="node-toolbar">
            <el-select v-model="nodeFilters.status" placeholder="节点状态" clearable style="width: 150px" @change="loadNodes">
              <el-option label="待开始" value="pending" />
              <el-option label="进行中" value="in_progress" />
              <el-option label="待验收" value="pending_review" />
              <el-option label="已完成" value="completed" />
              <el-option label="已暂停" value="paused" />
            </el-select>
            <el-select v-model="nodeFilters.phase" placeholder="阶段" clearable style="width: 150px" @change="loadNodes">
              <el-option v-for="item in phaseOptions" :key="item.value" :label="item.label" :value="item.value" />
            </el-select>
          </div>

          <el-table :data="nodes" v-loading="nodeLoading" class="progress-table" style="width: 100%">
            <el-table-column prop="title" label="节点" min-width="180">
              <template #default="{ row }">
                <div class="node-title-cell">
                  <strong>{{ row.title }}</strong>
                  <span>{{ phaseLabel(row.phase) }}</span>
                </div>
              </template>
            </el-table-column>
            <el-table-column label="负责人" width="120">
              <template #default="{ row }">{{ row.assignee_name || '未指派' }}</template>
            </el-table-column>
            <el-table-column label="进度" width="160">
              <template #default="{ row }">
                <el-progress :percentage="Number(row.progress_percent || 0)" :stroke-width="8" />
              </template>
            </el-table-column>
            <el-table-column label="状态" width="110">
              <template #default="{ row }">
                <el-tag :type="statusType(row.status)" round>{{ statusLabel(row.status) }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="计划结束" width="120">
              <template #default="{ row }">{{ formatDate(row.plan_end_date) || '-' }}</template>
            </el-table-column>
            <el-table-column label="验收备注" min-width="140">
              <template #default="{ row }">{{ row.review_note || '-' }}</template>
            </el-table-column>
            <el-table-column label="操作" width="280" fixed="right">
              <template #default="{ row }">
                <el-button text type="primary" size="small" @click="openReports(row)">上报记录</el-button>
                <el-button text type="primary" size="small" @click="openNodeDialog(row)">编辑</el-button>
                <el-button
                  v-if="row.status === 'pending_review'"
                  text
                  type="success"
                  size="small"
                  @click="reviewNode(row, 'approve')"
                >通过</el-button>
                <el-button
                  v-if="row.status === 'pending_review'"
                  text
                  type="warning"
                  size="small"
                  @click="reviewNode(row, 'reject')"
                >驳回</el-button>
                <el-button text type="danger" size="small" @click="removeNode(row)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>

          <div class="recent-section">
            <h3>最近上报</h3>
            <div class="report-list">
              <div v-for="report in recentReports" :key="report.id" class="report-item">
                <div>
                  <strong>{{ report.nodeTitle || report.node_title || '节点上报' }}</strong>
                  <p>{{ report.description || '无描述' }}</p>
                  <span>{{ report.reporterName || report.reporter_name || '未知人员' }} · {{ formatDateTime(report.createdAt || report.created_at) }}</span>
                </div>
                <el-tag type="primary" round>{{ report.progressPercent || report.progress_percent || 0 }}%</el-tag>
              </div>
              <el-empty v-if="recentReports.length === 0" description="暂无上报记录" />
            </div>
          </div>
        </template>

        <el-empty v-else description="请选择项目查看进度" />
      </div>
    </div>

    <el-dialog
      v-model="nodeDialogVisible"
      :title="editingNode ? '编辑节点' : '创建节点'"
      width="620px"
      :close-on-click-modal="false"
    >
      <el-form ref="nodeFormRef" :model="nodeForm" :rules="nodeRules" label-width="92px">
        <el-form-item label="节点标题" prop="title">
          <el-input v-model="nodeForm.title" placeholder="请输入节点标题" />
        </el-form-item>
        <el-form-item label="阶段">
          <el-select v-model="nodeForm.phase" placeholder="请选择阶段" style="width: 100%">
            <el-option v-for="item in phaseOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="负责人">
          <el-select v-model="nodeForm.assignee_id" clearable filterable placeholder="请选择负责人" style="width: 100%">
            <el-option
              v-for="user in workerOptions"
              :key="user.id"
              :label="`${user.name || user.username}（${user.username}）`"
              :value="user.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="计划日期">
          <el-date-picker
            v-model="nodeDateRange"
            type="daterange"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            value-format="YYYY-MM-DD"
            style="width: 100%"
          />
        </el-form-item>
        <el-form-item label="优先级">
          <el-select v-model="nodeForm.priority" placeholder="请选择优先级" style="width: 100%">
            <el-option label="高" value="high" />
            <el-option label="中" value="medium" />
            <el-option label="低" value="low" />
          </el-select>
        </el-form-item>
        <el-form-item v-if="editingNode" label="状态">
          <el-select v-model="nodeForm.status" style="width: 100%">
            <el-option label="待开始" value="pending" />
            <el-option label="进行中" value="in_progress" />
            <el-option label="待验收" value="pending_review" />
            <el-option label="已完成" value="completed" />
            <el-option label="已暂停" value="paused" />
          </el-select>
        </el-form-item>
        <el-form-item v-if="editingNode" label="进度">
          <el-slider v-model="nodeForm.progress_percent" :min="0" :max="100" show-input />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="nodeForm.description" type="textarea" :rows="3" placeholder="请输入节点说明" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="nodeDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="nodeSaving" @click="saveNode">保存</el-button>
      </template>
    </el-dialog>

    <el-drawer v-model="reportsDrawerVisible" :title="reportsTitle" size="520px">
      <div v-loading="reportsLoading" class="reports-drawer-body">
        <div v-for="report in reports" :key="report.id" class="report-card">
          <div class="report-card-header">
            <strong>{{ report.reporter_name || '未知人员' }}</strong>
            <el-tag type="primary" round>{{ report.progress_percent || 0 }}%</el-tag>
          </div>
          <p>{{ report.description || '无描述' }}</p>
          <div v-if="report.risk_note" class="report-note danger">风险：{{ report.risk_note }}</div>
          <div v-if="report.blocker_note" class="report-note warning">阻塞：{{ report.blocker_note }}</div>
          <div class="photo-row">
            <el-image
              v-for="photo in reportPhotos(report)"
              :key="photo"
              :src="getPhotoUrl(photo)"
              fit="cover"
              class="report-photo"
              :preview-src-list="reportPhotos(report).map(getPhotoUrl)"
              preview-teleported
            />
          </div>
          <span class="report-time">{{ formatDateTime(report.created_at) }}</span>
        </div>
        <el-empty v-if="reports.length === 0 && !reportsLoading" description="暂无上报记录" />
      </div>
    </el-drawer>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Refresh, Search } from '@element-plus/icons-vue'
import {
  createProjectNode,
  deleteProjectNode,
  getNodeReports,
  getProgressProjects,
  getProjectNodes,
  getProjectSummary,
  reviewProjectNode,
  updateProjectNode
} from '@/api/progress'
import { getUsers } from '@/api/users'

const route = useRoute()
const loading = ref(false)
const nodeLoading = ref(false)
const nodeSaving = ref(false)
const reportsLoading = ref(false)
const keyword = ref('')
const projects = ref([])
const activeProject = ref(null)
const summary = ref({})
const nodes = ref([])
const recentReports = ref([])
const workerOptions = ref([])
const nodeDialogVisible = ref(false)
const editingNode = ref(null)
const nodeFormRef = ref(null)
const nodeDateRange = ref([])
const reportsDrawerVisible = ref(false)
const reportsTitle = ref('上报记录')
const reports = ref([])
const nodeFilters = reactive({ status: '', phase: '' })

const phaseOptions = [
  { value: 'preparation', label: '准备阶段' },
  { value: 'construction', label: '施工阶段' },
  { value: 'inspection', label: '验收阶段' },
  { value: 'rectification', label: '整改阶段' },
  { value: 'delivery', label: '交付阶段' }
]

const nodeForm = reactive({
  title: '',
  description: '',
  assignee_id: null,
  status: 'pending',
  progress_percent: 0,
  phase: 'construction',
  priority: 'medium'
})

const nodeRules = {
  title: [{ required: true, message: '请输入节点标题', trigger: 'blur' }]
}

const filteredProjects = computed(() => {
  const text = keyword.value.trim().toLowerCase()
  if (!text) return projects.value
  return projects.value.filter((project) => {
    return `${project.name || ''}${project.address || ''}`.toLowerCase().includes(text)
  })
})

onMounted(async () => {
  await loadProjects()
})

watch(() => route.query.projectId, async (projectId) => {
  if (!projectId || projects.value.length === 0) return
  const project = projects.value.find((item) => String(item.id) === String(projectId))
  if (project) await selectProject(project)
})

async function loadProjects() {
  loading.value = true
  try {
    const res = await getProgressProjects()
    projects.value = res.data.projects || []
    if (projects.value.length > 0) {
      const queryProject = route.query.projectId
      const next = projects.value.find((item) => String(item.id) === String(queryProject)) || activeProject.value || projects.value[0]
      await selectProject(next)
    } else {
      activeProject.value = null
      nodes.value = []
      summary.value = {}
      recentReports.value = []
    }
  } catch (e) {
    ElMessage.error(e.response?.data?.message || e.message || '加载项目进度失败')
  } finally {
    loading.value = false
  }
}

async function selectProject(project) {
  activeProject.value = project
  nodeFilters.status = ''
  nodeFilters.phase = ''
  await loadProjectDetail()
}

async function loadProjectDetail() {
  if (!activeProject.value) return
  await Promise.all([loadSummary(), loadNodes(), loadWorkers()])
}

async function loadSummary() {
  const res = await getProjectSummary(activeProject.value.id)
  summary.value = res.data || {}
  recentReports.value = summary.value.recentReports || []
}

async function loadNodes() {
  nodeLoading.value = true
  try {
    const params = { page: 1, pageSize: 200 }
    if (nodeFilters.status) params.status = nodeFilters.status
    if (nodeFilters.phase) params.phase = nodeFilters.phase
    const res = await getProjectNodes(activeProject.value.id, params)
    nodes.value = res.data.list || []
  } catch (e) {
    ElMessage.error(e.response?.data?.message || e.message || '加载节点失败')
  } finally {
    nodeLoading.value = false
  }
}

async function loadWorkers() {
  try {
    const res = await getUsers({ role: 'worker', project_id: activeProject.value.id, status: 1, page: 1, pageSize: 1000 })
    workerOptions.value = res.data.list || []
  } catch (_) {
    workerOptions.value = []
  }
}

function openNodeDialog(node = null) {
  editingNode.value = node
  if (node) {
    Object.assign(nodeForm, {
      title: node.title || '',
      description: node.description || '',
      assignee_id: node.assignee_id || null,
      status: node.status || 'pending',
      progress_percent: Number(node.progress_percent || 0),
      phase: node.phase || 'construction',
      priority: node.priority || 'medium'
    })
    nodeDateRange.value = [formatDate(node.plan_start_date), formatDate(node.plan_end_date)].filter(Boolean)
  } else {
    Object.assign(nodeForm, {
      title: '',
      description: '',
      assignee_id: null,
      status: 'pending',
      progress_percent: 0,
      phase: 'construction',
      priority: 'medium'
    })
    nodeDateRange.value = []
  }
  nodeDialogVisible.value = true
}

async function saveNode() {
  const valid = await nodeFormRef.value?.validate().catch(() => false)
  if (!valid || !activeProject.value) return

  const payload = {
    ...nodeForm,
    assignee_id: nodeForm.assignee_id || null,
    plan_start_date: nodeDateRange.value?.[0] || null,
    plan_end_date: nodeDateRange.value?.[1] || null
  }

  nodeSaving.value = true
  try {
    if (editingNode.value) {
      await updateProjectNode(editingNode.value.id, payload)
      ElMessage.success('节点已更新')
    } else {
      await createProjectNode(activeProject.value.id, payload)
      ElMessage.success('节点已创建')
    }
    nodeDialogVisible.value = false
    await refreshActiveProject()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || e.message || '保存节点失败')
  } finally {
    nodeSaving.value = false
  }
}

async function removeNode(node) {
  await ElMessageBox.confirm(`确定删除节点「${node.title}」？`, '删除节点', { type: 'warning' })
  try {
    await deleteProjectNode(node.id)
    ElMessage.success('节点已删除')
    await refreshActiveProject()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || e.message || '删除节点失败')
  }
}

async function reviewNode(node, action) {
  const title = action === 'approve' ? '验收通过' : '驳回继续施工'
  const { value } = await ElMessageBox.prompt(`请输入${title}备注`, title, {
    inputType: 'textarea',
    inputPlaceholder: '可选',
    confirmButtonText: '确认',
    cancelButtonText: '取消'
  }).catch(() => ({ value: null }))
  if (value === null) return

  try {
    await reviewProjectNode(node.id, { action, remark: value || '' })
    ElMessage.success(action === 'approve' ? '验收已通过' : '已驳回')
    await refreshActiveProject()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || e.message || '验收操作失败')
  }
}

async function openReports(node) {
  reportsTitle.value = `${node.title} · 上报记录`
  reportsDrawerVisible.value = true
  reportsLoading.value = true
  try {
    const res = await getNodeReports(node.id, { page: 1, pageSize: 100 })
    reports.value = res.data.list || []
  } catch (e) {
    ElMessage.error(e.response?.data?.message || e.message || '加载上报记录失败')
  } finally {
    reportsLoading.value = false
  }
}

async function refreshActiveProject() {
  await Promise.all([loadSummary(), loadNodes(), loadProjects()])
}

function phaseLabel(value) {
  return phaseOptions.find((item) => item.value === value)?.label || '未分阶段'
}

function statusLabel(status) {
  const map = {
    pending: '待开始',
    in_progress: '进行中',
    pending_review: '待验收',
    completed: '已完成',
    paused: '已暂停'
  }
  return map[status] || status || '-'
}

function statusType(status) {
  const map = {
    pending: 'info',
    in_progress: 'primary',
    pending_review: 'warning',
    completed: 'success',
    paused: 'danger'
  }
  return map[status] || 'info'
}

function formatDate(value) {
  if (!value) return ''
  return String(value).slice(0, 10)
}

function formatDateTime(value) {
  if (!value) return ''
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return String(value)
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
}

function reportPhotos(report) {
  const photos = []
  if (report.photo) photos.push(report.photo)
  if (report.photos) {
    try {
      const parsed = typeof report.photos === 'string' ? JSON.parse(report.photos) : report.photos
      if (Array.isArray(parsed)) photos.push(...parsed)
    } catch (_) {}
  }
  return [...new Set(photos.filter(Boolean))]
}

function getPhotoUrl(photo) {
  if (!photo) return ''
  if (photo.startsWith('http')) return photo
  const baseUrl = import.meta.env.VITE_API_BASE_URL || window.location.origin
  return `${baseUrl}${photo}`
}
</script>

<style scoped>
.header-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.progress-layout {
  display: grid;
  grid-template-columns: 360px minmax(0, 1fr);
  gap: 18px;
  margin-top: 22px;
}

.project-list-panel,
.detail-panel {
  background: var(--bg-card);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-lg);
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.18);
  min-height: 560px;
}

.project-list-panel {
  padding: 14px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.detail-panel {
  padding: 20px;
  overflow: hidden;
}

.progress-project-card {
  border: 1px solid var(--border-light);
  border-radius: 8px;
  padding: 14px;
  cursor: pointer;
  transition: var(--transition);
  background: rgba(255, 255, 255, 0.04);
}

.progress-project-card:hover,
.progress-project-card.active {
  border-color: rgba(79, 140, 255, 0.55);
  background: rgba(79, 140, 255, 0.1);
}

.project-card-title,
.detail-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
}

.project-card-title h3,
.detail-header h3,
.recent-section h3 {
  margin: 0;
  color: var(--text-primary);
  font-size: 17px;
  font-weight: 700;
}

.project-card-title p,
.detail-header p {
  margin: 6px 0 0;
  color: var(--text-secondary);
  font-size: 13px;
}

.project-stat-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 6px;
  margin-top: 14px;
  font-size: 12px;
  color: var(--text-secondary);
}

.project-stat-row span {
  padding: 5px 6px;
  border-radius: 6px;
  background: rgba(255, 255, 255, 0.05);
  text-align: center;
}

.project-stat-row .warning {
  color: #e6a23c;
}

.project-stat-row .danger {
  color: #f56c6c;
}

.project-meta {
  margin-top: 12px;
  color: var(--text-muted);
  font-size: 12px;
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
  margin: 20px 0;
}

.summary-item {
  border: 1px solid var(--border-light);
  border-radius: 8px;
  padding: 14px;
  background: rgba(255, 255, 255, 0.04);
}

.summary-item span {
  display: block;
  color: var(--text-secondary);
  font-size: 13px;
  margin-bottom: 8px;
}

.summary-item strong {
  color: var(--text-primary);
  font-size: 24px;
}

.node-toolbar {
  display: flex;
  gap: 10px;
  margin-bottom: 12px;
}

.node-title-cell {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.node-title-cell span {
  color: var(--text-muted);
  font-size: 12px;
}

.recent-section {
  margin-top: 22px;
}

.report-list,
.reports-drawer-body {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.report-item,
.report-card {
  border: 1px solid var(--border-light);
  border-radius: 8px;
  padding: 14px;
  background: rgba(255, 255, 255, 0.04);
}

.report-item {
  display: flex;
  justify-content: space-between;
  gap: 12px;
}

.report-item p,
.report-card p {
  margin: 6px 0;
  color: var(--text-secondary);
}

.report-item span,
.report-time {
  color: var(--text-muted);
  font-size: 12px;
}

.report-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.report-note {
  margin-top: 6px;
  font-size: 13px;
}

.report-note.warning {
  color: #e6a23c;
}

.report-note.danger {
  color: #f56c6c;
}

.photo-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin: 10px 0;
}

.report-photo {
  width: 82px;
  height: 82px;
  border-radius: 8px;
  overflow: hidden;
  cursor: zoom-in;
}

@media (max-width: 1100px) {
  .progress-layout {
    grid-template-columns: 1fr;
  }

  .summary-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>
