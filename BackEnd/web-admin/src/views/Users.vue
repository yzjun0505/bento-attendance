<template>
  <div class="page-container fade-in-up">
    <div class="unified-card">
      <div class="header-section">
        <div>
          <h2 class="page-title">人员管理</h2>
          <p class="page-subtitle">管理系统中的所有用户信息</p>
        </div>
        <el-button type="primary" :icon="Plus" @click="openDialog()">新增人员</el-button>
      </div>

      <!-- 搜索筛选 -->
      <div class="filter-section">
        <el-input
          v-model="filters.keyword"
          placeholder="搜索姓名/用户名/手机号"
          :prefix-icon="Search"
          clearable
          style="width: 240px"
          @clear="loadData"
          @keyup.enter="loadData"
        />
        <el-select v-model="filters.role" placeholder="角色" clearable style="width: 130px" @change="loadData">
          <el-option label="管理员" value="admin" />
          <el-option label="项目经理" value="manager" />
          <el-option label="工人" value="worker" />
        </el-select>
        <el-select v-model="filters.status" placeholder="状态" clearable style="width: 130px" @change="loadData">
          <el-option label="在职" :value="1" />
          <el-option label="离职" :value="0" />
        </el-select>
        <el-select v-model="filters.project_id" placeholder="所属项目" clearable style="width: 130px" @change="loadData">
          <el-option v-for="p in projectList" :key="p.id" :label="p.name" :value="p.id" />
        </el-select>
        <el-button type="primary" :icon="Search" @click="loadData">搜索</el-button>
      </div>

      <!-- 用户表格 -->
      <div class="table-section">
        <el-table
          :data="tableData"
          v-loading="loading"
          class="custom-table"
          style="width: 100%"
        >
        <el-table-column prop="name" label="姓名" min-width="100">
          <template #default="{ row }">
            <div style="display: flex; align-items: center; gap: 8px;">
              <el-avatar :size="32" style="background: var(--gradient-blue); font-size: 13px; flex-shrink: 0;">
                {{ row.name?.charAt(0) || '?' }}
              </el-avatar>
              <span>{{ row.name }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="username" label="用户名" min-width="100" />
        <el-table-column prop="role" label="角色" width="110">
          <template #default="{ row }">
            <el-tag :class="'role-' + row.role" size="small" effect="dark" round>
              {{ roleMap[row.role] }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="phone" label="手机号" min-width="120" />
        <el-table-column prop="project_name" label="所属项目" min-width="140">
          <template #default="{ row }">
            {{ row.project_name || '—' }}
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="90">
          <template #default="{ row }">
            <span v-if="row.status === 1"><span class="online-dot"></span>在职</span>
            <span v-else><span class="offline-dot"></span>离职</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="140" fixed="right">
          <template #default="{ row }">
            <div class="table-actions">
              <el-button type="primary" link :icon="Edit" @click="openDialog(row)" title="编辑"></el-button>
              <el-button type="danger" link :icon="Delete" @click="handleDelete(row)" title="删除"></el-button>
              <el-dropdown trigger="click" @command="(cmd) => handleCommand(cmd, row)">
                <el-button link :icon="MoreFilled" style="margin-left: 8px; color: var(--text-secondary);"></el-button>
                <template #dropdown>
                  <el-dropdown-menu>
                    <el-dropdown-item v-if="isAdmin && row.role === 'manager'" command="authProjects">项目授权</el-dropdown-item>
                    <el-dropdown-item command="resetPwd">重置密码</el-dropdown-item>
                  </el-dropdown-menu>
                </template>
              </el-dropdown>
            </div>
          </template>
        </el-table-column>
      </el-table>

      <div style="padding: 16px; display: flex; justify-content: flex-end;">
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

    <!-- 新增/编辑弹窗 -->
    <el-dialog
      v-model="dialogVisible"
      :title="editingUser ? '编辑人员' : '新增人员'"
      width="520px"
      :close-on-click-modal="false"
    >
      <el-form ref="dialogFormRef" :model="dialogForm" :rules="dialogRules" label-width="80px">
        <el-form-item label="用户名" prop="username">
          <el-input v-model="dialogForm.username" :disabled="!!editingUser" placeholder="请输入用户名" />
        </el-form-item>
        <el-form-item v-if="!editingUser" label="密码" prop="password">
          <el-input v-model="dialogForm.password" type="password" placeholder="请输入密码" show-password />
        </el-form-item>
        <el-form-item label="姓名" prop="name">
          <el-input v-model="dialogForm.name" placeholder="请输入姓名" />
        </el-form-item>
        <el-form-item label="角色" prop="role">
          <el-select v-model="dialogForm.role" placeholder="请选择角色" style="width: 100%">
            <el-option label="管理员" value="admin" />
            <el-option label="项目经理" value="manager" />
            <el-option label="工人" value="worker" />
          </el-select>
        </el-form-item>
        <el-form-item label="手机号" prop="phone">
          <el-input v-model="dialogForm.phone" placeholder="请输入手机号" />
        </el-form-item>
        <el-form-item label="所属项目">
          <el-select v-model="dialogForm.project_id" placeholder="请选择项目" clearable style="width: 100%">
            <el-option v-for="p in projectList" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-form-item>
        <el-form-item v-if="editingUser" label="状态">
          <el-switch v-model="dialogForm.status" :active-value="1" :inactive-value="0" active-text="在职" inactive-text="离职" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog
      v-model="authDialogVisible"
      title="项目经理授权"
      width="520px"
      :close-on-click-modal="false"
    >
      <el-form label-width="90px">
        <el-form-item label="项目经理">
          <el-input :model-value="authorizingUser?.name || authorizingUser?.username || ''" disabled />
        </el-form-item>
        <el-form-item label="授权项目" required>
          <el-select
            v-model="selectedProjectIds"
            multiple
            filterable
            placeholder="请选择项目"
            style="width: 100%"
            :loading="authLoading"
          >
            <el-option v-for="p in projectList" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="authDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="authSaving" @click="handleSaveAuth">保存授权</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { getUsers, createUser, updateUser, deleteUser, resetPassword } from '@/api/users'
import { getAllProjects } from '@/api/projects'
import { getProjectManagers, bindProjectManager, unbindProjectManager } from '@/api/projectManagers'
import { useUserStore } from '@/store/user'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Search, Edit, Delete, MoreFilled } from '@element-plus/icons-vue'

const roleMap = { admin: '管理员', manager: '项目经理', worker: '工人' }

const loading = ref(false)
const saving = ref(false)
const authLoading = ref(false)
const authSaving = ref(false)
const tableData = ref([])
const projectList = ref([])
const dialogVisible = ref(false)
const authDialogVisible = ref(false)
const editingUser = ref(null)
const authorizingUser = ref(null)
const dialogFormRef = ref(null)
const authRows = ref([])
const selectedProjectIds = ref([])
const userStore = useUserStore()
const isAdmin = computed(() => userStore.userInfo?.role === 'admin')

const filters = reactive({ keyword: '', role: '', status: '', project_id: '' })
const pagination = reactive({ page: 1, pageSize: 20, total: 0 })

const dialogForm = reactive({
  username: '', password: '', name: '', role: 'worker', phone: '', project_id: null, status: 1
})

const dialogRules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }],
  name: [{ required: true, message: '请输入姓名', trigger: 'blur' }],
  role: [{ required: true, message: '请选择角色', trigger: 'change' }]
}

onMounted(() => {
  loadData()
  loadProjects()
})

async function loadData() {
  loading.value = true
  try {
    const res = await getUsers({ ...filters, ...pagination })
    tableData.value = res.data.list
    pagination.total = res.data.total
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '加载用户列表失败')
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

function openDialog(user = null) {
  editingUser.value = user
  if (user) {
    Object.assign(dialogForm, { ...user, password: '' })
  } else {
    Object.assign(dialogForm, { username: '', password: '', name: '', role: 'worker', phone: '', project_id: null, status: 1 })
  }
  dialogVisible.value = true
}

async function handleSave() {
  const valid = await dialogFormRef.value?.validate().catch(() => false)
  if (!valid) return

  saving.value = true
  try {
    if (editingUser.value) {
      const { username, password, ...data } = dialogForm
      await updateUser(editingUser.value.id, data)
      ElMessage.success('更新成功')
    } else {
      await createUser(dialogForm)
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
  await ElMessageBox.confirm(`确定删除用户「${row.name}」？`, '警告', { type: 'warning' })
  try {
    await deleteUser(row.id)
    ElMessage.success('删除成功')
    loadData()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '删除失败')
  }
}

async function handleResetPwd(row) {
  const { value } = await ElMessageBox.prompt('请输入新密码', `重置「${row.name}」密码`, {
    inputPattern: /^.{6,}$/,
    inputErrorMessage: '密码至少6位',
    confirmButtonText: '确定',
    cancelButtonText: '取消'
  })
  try {
    await resetPassword(row.id, { password: value })
    ElMessage.success('密码已重置')
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '重置密码失败')
  }
}

function handleCommand(command, row) {
  if (command === 'resetPwd') {
    handleResetPwd(row)
  } else if (command === 'authProjects') {
    openAuthDialog(row)
  }
}

async function openAuthDialog(user) {
  if (user.role !== 'manager') {
    ElMessage.warning('只有项目经理可以进行项目授权')
    return
  }
  authorizingUser.value = user
  authDialogVisible.value = true
  authLoading.value = true
  try {
    if (projectList.value.length === 0) {
      await loadProjects()
    }
    const res = await getProjectManagers({ manager_id: user.id })
    authRows.value = res.data || []
    selectedProjectIds.value = authRows.value.map((item) => item.project_id)
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '加载授权信息失败')
  } finally {
    authLoading.value = false
  }
}

async function handleSaveAuth() {
  if (!authorizingUser.value) return
  if (selectedProjectIds.value.length === 0) {
    ElMessage.warning('请至少选择一个授权项目')
    return
  }

  const currentIds = new Set(authRows.value.map((item) => item.project_id))
  const nextIds = new Set(selectedProjectIds.value)
  const additions = selectedProjectIds.value.filter((id) => !currentIds.has(id))
  const removals = authRows.value.filter((item) => !nextIds.has(item.project_id))

  authSaving.value = true
  try {
    await Promise.all([
      ...additions.map((projectId) => bindProjectManager({
        manager_id: authorizingUser.value.id,
        project_id: projectId
      })),
      ...removals.map((item) => unbindProjectManager(item.id))
    ])
    ElMessage.success('项目授权已更新')
    authDialogVisible.value = false
    await loadData()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || e.message || '保存授权失败')
  } finally {
    authSaving.value = false
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

.table-actions {
  display: flex;
  align-items: center;
  gap: 4px;
}
</style>
