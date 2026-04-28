<template>
  <div class="page-container fade-in-up">
    <div class="page-header">
      <div>
        <h2 class="page-title">项目管理</h2>
        <p class="page-subtitle">管理项目信息和电子围栏设置</p>
      </div>
      <el-button type="primary" :icon="Plus" @click="openDialog()">新增项目</el-button>
    </div>

    <!-- 筛选 -->
    <div class="filter-bar">
      <el-input
        v-model="filters.keyword"
        placeholder="搜索项目名称/地址"
        :prefix-icon="Search"
        clearable
        style="width: 260px"
        @clear="loadData"
        @keyup.enter="loadData"
      />
      <el-select v-model="filters.status" placeholder="状态" clearable style="width: 120px" @change="loadData">
        <el-option label="启用" :value="1" />
        <el-option label="停用" :value="0" />
      </el-select>
      <el-button type="primary" :icon="Search" @click="loadData">搜索</el-button>
    </div>

    <!-- 项目列表卡片 -->
    <div class="projects-grid">
      <div
        v-for="project in tableData"
        :key="project.id"
        class="project-card"
        :class="{ disabled: project.status === 0 }"
      >
        <div class="project-card-header">
          <div class="project-name-row">
            <el-icon :size="18" color="#4f8cff"><OfficeBuilding /></el-icon>
            <h3>{{ project.name }}</h3>
          </div>
          <el-tag v-if="project.status === 1" type="success" size="small" round effect="dark">启用</el-tag>
          <el-tag v-else type="info" size="small" round effect="dark">停用</el-tag>
        </div>

        <div class="project-card-body">
          <div class="project-info-item">
            <el-icon><Location /></el-icon>
            <span>{{ project.address || '未设置地址' }}</span>
          </div>
          <div class="project-info-item">
            <el-icon><Aim /></el-icon>
            <span>围栏半径: {{ project.radius || 500 }}米</span>
          </div>
          <div class="project-info-item">
            <el-icon><User /></el-icon>
            <span>关联人员: {{ project.user_count || 0 }}人</span>
          </div>
        </div>

        <div class="project-card-footer">
          <el-button type="primary" text size="small" @click="openDialog(project)">
            <el-icon><Edit /></el-icon>编辑
          </el-button>
          <el-button type="danger" text size="small" @click="handleDelete(project)">
            <el-icon><Delete /></el-icon>删除
          </el-button>
        </div>
      </div>
    </div>

    <div v-if="tableData.length === 0 && !loading" class="empty-projects">
      <el-icon :size="48" color="#5f6477"><OfficeBuilding /></el-icon>
      <p>暂无项目，点击右上角新增</p>
    </div>

    <div v-if="pagination.total > pagination.pageSize" style="padding: 20px; display: flex; justify-content: center;">
      <el-pagination
        v-model:current-page="pagination.page"
        v-model:page-size="pagination.pageSize"
        :total="pagination.total"
        layout="prev, pager, next"
        background
        @current-change="loadData"
      />
    </div>

    <!-- 新增/编辑弹窗 -->
    <el-dialog
      v-model="dialogVisible"
      :title="editingProject ? '编辑项目' : '新增项目'"
      width="560px"
      :close-on-click-modal="false"
    >
      <el-form ref="dialogFormRef" :model="dialogForm" :rules="dialogRules" label-width="90px">
        <el-form-item label="项目名称" prop="name">
          <el-input v-model="dialogForm.name" placeholder="请输入项目名称" />
        </el-form-item>
        <el-form-item label="项目地址" prop="address">
          <el-input v-model="dialogForm.address" placeholder="请输入项目地址" />
        </el-form-item>
        <el-form-item label="中心纬度">
          <el-input-number v-model="dialogForm.latitude" :precision="6" :step="0.000001" style="width: 100%" placeholder="纬度" />
        </el-form-item>
        <el-form-item label="中心经度">
          <div style="display: flex; gap: 8px; width: 100%">
            <el-input-number v-model="dialogForm.longitude" :precision="6" :step="0.000001" style="flex: 1;" placeholder="经度" />
            <el-button type="primary" :icon="Location" @click="showAmapSelector">选取坐标</el-button>
          </div>
        </el-form-item>
        <el-form-item label="围栏半径">
          <el-input-number v-model="dialogForm.radius" :min="50" :max="10000" :step="50" style="width: 100%">
            <template #append>米</template>
          </el-input-number>
        </el-form-item>
        <el-form-item label="项目描述">
          <el-input v-model="dialogForm.description" type="textarea" :rows="3" placeholder="请输入项目描述" />
        </el-form-item>
        <el-form-item v-if="editingProject" label="状态">
          <el-switch v-model="dialogForm.status" :active-value="1" :inactive-value="0" active-text="启用" inactive-text="停用" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>

    <AmapSelector v-model="amapDialogVisible" :initial-lat="dialogForm.latitude" :initial-lng="dialogForm.longitude" @select="handleAmapSelect" />
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { getProjects, createProject, updateProject, deleteProject } from '@/api/projects'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Search, OfficeBuilding, Location, Aim, User, Edit, Delete } from '@element-plus/icons-vue'
import AmapSelector from '@/components/AmapSelector.vue'

const loading = ref(false)
const saving = ref(false)
const tableData = ref([])
const dialogVisible = ref(false)
const editingProject = ref(null)
const dialogFormRef = ref(null)

const filters = reactive({ keyword: '', status: '' })
const pagination = reactive({ page: 1, pageSize: 20, total: 0 })

const dialogForm = reactive({
  name: '', address: '', latitude: null, longitude: null, radius: 500, description: '', status: 1
})

const dialogRules = {
  name: [{ required: true, message: '请输入项目名称', trigger: 'blur' }]
}

const amapDialogVisible = ref(false)

function showAmapSelector() {
  amapDialogVisible.value = true
}

function handleAmapSelect(location) {
  dialogForm.latitude = location.lat
  dialogForm.longitude = location.lng
  if (!dialogForm.address && location.address) {
    dialogForm.address = location.address
  }
}

onMounted(() => loadData())

async function loadData() {
  loading.value = true
  try {
    const res = await getProjects({ ...filters, ...pagination })
    tableData.value = res.data.list
    pagination.total = res.data.total
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '加载项目列表失败')
  } finally {
    loading.value = false
  }
}

function openDialog(project = null) {
  editingProject.value = project
  if (project) {
    Object.assign(dialogForm, { ...project })
  } else {
    Object.assign(dialogForm, { name: '', address: '', latitude: null, longitude: null, radius: 500, description: '', status: 1 })
  }
  dialogVisible.value = true
}

async function handleSave() {
  const valid = await dialogFormRef.value?.validate().catch(() => false)
  if (!valid) return

  saving.value = true
  try {
    if (editingProject.value) {
      await updateProject(editingProject.value.id, dialogForm)
      ElMessage.success('更新成功')
    } else {
      await createProject(dialogForm)
      ElMessage.success('创建成功')
    }
    dialogVisible.value = false
    loadData()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '保存失败')
  } finally {
    saving.value = false
  }
}

async function handleDelete(row) {
  await ElMessageBox.confirm(`确定删除项目「${row.name}」？`, '警告', { type: 'warning' })
  try {
    await deleteProject(row.id)
    ElMessage.success('删除成功')
    loadData()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '删除失败')
  }
}
</script>

<style scoped>
.projects-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
  gap: 16px;
}

.project-card {
  background: var(--bg-card);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-lg);
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.2);
  overflow: hidden;
  transition: var(--transition);
}

.project-card:hover {
  border-color: rgba(79, 140, 255, 0.3);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
  transform: translateY(-4px);
}

.project-card.disabled {
  opacity: 0.6;
}

.project-card-header {
  padding: 20px 20px 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.project-name-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.project-name-row h3 {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
}

.project-card-body {
  padding: 16px 20px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.project-info-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: var(--text-secondary);
}

.project-card-footer {
  padding: 12px 20px;
  border-top: 1px solid var(--border-color);
  display: flex;
  gap: 8px;
}

.empty-projects {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 80px 20px;
  color: var(--text-muted);
  gap: 12px;
  font-size: 14px;
}
</style>
