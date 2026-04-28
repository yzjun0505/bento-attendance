<template>
  <div class="page-container">
    <div class="filter-bar module-card">
      <el-form :inline="true" :model="queryParams" class="demo-form-inline">
        <el-form-item label="设备名称/ID">
          <el-input v-model="queryParams.keyword" placeholder="搜索名称或代码" clearable @keyup.enter="handleQuery" />
        </el-form-item>
        <el-form-item label="所属项目">
          <el-select v-model="queryParams.project_id" placeholder="全部项目" clearable style="width: 160px">
            <el-option v-for="p in projectList" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="设备类型">
          <el-select v-model="queryParams.type" placeholder="全部类型" clearable style="width: 140px">
            <el-option label="考勤闸机" value="checkpoint" />
            <el-option label="蓝牙信标" value="beacon" />
            <el-option label="监控摄头" value="camera" />
            <el-option label="其他设备" value="other" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="queryParams.status" placeholder="全部" clearable style="width: 100px">
            <el-option label="在线/正常" value="1" />
            <el-option label="离线/停用" value="0" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleQuery" :icon="Search">搜索</el-button>
          <el-button @click="resetQuery" :icon="Refresh">重置</el-button>
          <el-button type="success" @click="handleAdd" :icon="Plus" v-if="userStore.isAdmin || userStore.isManager">新增设备</el-button>
        </el-form-item>
      </el-form>
    </div>

    <!-- 列表区 -->
    <div class="table-card module-card">
      <el-table v-loading="loading" :data="deviceList" style="width: 100%" class="custom-table" empty-text="暂无设备数据">
        <el-table-column prop="device_id" label="设备硬件ID/MAC" width="180" />
        <el-table-column prop="name" label="设备名称" min-width="150" />
        <el-table-column prop="type" label="类型" width="120">
          <template #default="{ row }">
            <el-tag :type="getTypeTag(row.type)" effect="plain">{{ getTypeName(row.type) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="project_name" label="绑定项目" min-width="180">
          <template #default="{ row }">
            <span v-if="row.project_id">{{ row.project_name }}</span>
            <span v-else class="text-muted">未绑定全局设备</span>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'danger'" effect="dark">
              {{ row.status === 1 ? '正常' : '离线' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="last_active" label="最后活跃时间" width="180">
          <template #default="{ row }">
            <span v-if="row.last_active">{{ row.last_active }}</span>
            <span v-else class="text-muted">尚未激活</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="160" fixed="right">
          <template #default="{ row }">
            <div class="table-actions">
              <el-button link type="primary" @click="handleEdit(row)" v-if="userStore.isAdmin || userStore.isManager">编辑</el-button>
              <el-button link type="danger" @click="handleDelete(row)" v-if="userStore.isAdmin">删除</el-button>
            </div>
          </template>
        </el-table-column>
      </el-table>

      <!-- 分页组件 -->
      <div class="pagination-wrapper">
        <el-pagination
          v-model:current-page="queryParams.page"
          v-model:page-size="queryParams.pageSize"
          :page-sizes="[10, 20, 50, 100]"
          layout="total, sizes, prev, pager, next, jumper"
          :total="total"
          @size-change="getList"
          @current-change="getList"
          background
        />
      </div>
    </div>

    <!-- 新增/编辑弹窗 -->
    <el-dialog :title="dialog.title" v-model="dialog.visible" width="500px" style="border-radius: var(--radius-lg); background: var(--bg-card); backdrop-filter: blur(24px);" :show-close="false">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="设备名称" prop="name">
          <el-input v-model="form.name" placeholder="请输入设备名称" />
        </el-form-item>
        <el-form-item label="设备编码" prop="device_id">
          <el-input v-model="form.device_id" placeholder="MAC地址或唯一序列号" :disabled="dialog.type === 'edit'" />
        </el-form-item>
        <el-form-item label="设备类型" prop="type">
          <el-select v-model="form.type" placeholder="请选择类型" style="width:100%">
            <el-option label="考勤闸机" value="checkpoint" />
            <el-option label="蓝牙信标" value="beacon" />
            <el-option label="监控摄头" value="camera" />
            <el-option label="其他设备" value="other" />
          </el-select>
        </el-form-item>
        <el-form-item label="绑定项目" prop="project_id">
          <el-select v-model="form.project_id" placeholder="不绑定即为全局设备" clearable style="width:100%">
            <el-option v-for="p in projectList" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="设备定位">
          <div style="display: flex; gap: 8px; width: 100%">
            <el-input v-model="form.latitude" placeholder="经度(Latitude)" style="flex:1" />
            <el-input v-model="form.longitude" placeholder="纬度(Longitude)" style="flex:1" />
            <el-button type="primary" :icon="Location" @click="showAmapSelector">选取坐标</el-button>
          </div>
          <div class="form-tip">定位坐标暂供后期项目定位与轨迹追踪使用</div>
        </el-form-item>
        <el-form-item label="状态" prop="status">
          <el-radio-group v-model="form.status">
            <el-radio :label="1">在线/正常</el-radio>
            <el-radio :label="0">离线/停用</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="dialog.visible = false">取消</el-button>
          <el-button type="primary" @click="submitForm" :loading="submitLoading">确定</el-button>
        </div>
      </template>
    </el-dialog>

    <AmapSelector v-model="amapDialogVisible" :initial-lat="form.latitude" :initial-lng="form.longitude" @select="handleAmapSelect" />
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { Search, Plus, Refresh, Location } from '@element-plus/icons-vue'
import { getDevices, createDevice, updateDevice, deleteDevice } from '@/api/devices'
import { getAllProjects } from '@/api/projects'
import { useUserStore } from '@/store/user'
import { ElMessage, ElMessageBox } from 'element-plus'
import AmapSelector from '@/components/AmapSelector.vue'

const userStore = useUserStore()

// 查询参数
const queryParams = reactive({
  page: 1,
  pageSize: 10,
  keyword: '',
  status: '',
  type: '',
  project_id: ''
})

const loading = ref(false)
const deviceList = ref([])
const total = ref(0)
const projectList = ref([])

// 弹窗控制
const dialog = reactive({
  visible: false,
  title: '',
  type: ''
})
const submitLoading = ref(false)
const formRef = ref(null)

const form = reactive({
  id: null,
  device_id: '',
  name: '',
  type: 'checkpoint',
  project_id: '',
  status: 1,
  latitude: '',
  longitude: ''
})

const rules = {
  name: [{ required: true, message: '请输入设备名称', trigger: 'blur' }],
  device_id: [{ required: true, message: '请输入设备MAC码', trigger: 'blur' }],
  type: [{ required: true, message: '请选择设备类型', trigger: 'change' }]
}

const amapDialogVisible = ref(false)

function showAmapSelector() {
  amapDialogVisible.value = true
}

function handleAmapSelect(location) {
  form.latitude = location.lat
  form.longitude = location.lng
}

onMounted(() => {
  fetchProjects()
  getList()
})

async function fetchProjects() {
  try {
    const res = await getAllProjects()
    if (res.code === 200) {
      projectList.value = res.data
    }
  } catch (error) {
    console.error('获取项目字典失败', error)
  }
}

async function getList() {
  loading.value = true
  try {
    const res = await getDevices(queryParams)
    if (res.code === 200) {
      deviceList.value = res.data.list
      total.value = res.data.total
    }
  } catch (error) {
    ElMessage.error('获取设备列表失败')
  } finally {
    loading.value = false
  }
}

function handleQuery() {
  queryParams.page = 1
  getList()
}

function resetQuery() {
  queryParams.keyword = ''
  queryParams.status = ''
  queryParams.type = ''
  queryParams.project_id = ''
  handleQuery()
}

function handleAdd() {
  dialog.type = 'add'
  dialog.title = '新增设备'
  Object.assign(form, {
    id: null,
    device_id: '',
    name: '',
    type: 'checkpoint',
    project_id: '',
    status: 1,
    latitude: '',
    longitude: ''
  })
  dialog.visible = true
}

function handleEdit(row) {
  dialog.type = 'edit'
  dialog.title = '编辑设备'
  Object.assign(form, { ...row, project_id: row.project_id || '' })
  dialog.visible = true
}

function handleDelete(row) {
  ElMessageBox.confirm(`确认删除设备 "${row.name}" 吗？`, '警告', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  }).then(async () => {
    try {
      const res = await deleteDevice(row.id)
      if (res.code === 200) {
        ElMessage.success('删除成功')
        getList()
      } else {
        ElMessage.error(res.message || '删除失败')
      }
    } catch (e) {
      ElMessage.error('系统异常')
    }
  }).catch(() => {})
}

async function submitForm() {
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (valid) {
      submitLoading.value = true
      try {
        let res
        if (dialog.type === 'add') {
          res = await createDevice(form)
        } else {
          res = await updateDevice(form.id, form)
        }

        if (res.code === 200) {
          ElMessage.success(dialog.type === 'add' ? '新增成功' : '修改成功')
          dialog.visible = false
          getList()
        } else {
          ElMessage.error(res.message || '操作失败')
        }
      } catch (error) {
        ElMessage.error('系统异常')
      } finally {
        submitLoading.value = false
      }
    }
  })
}

// 辅助方法
function getTypeName(type) {
  const map = {
    checkpoint: '考勤闸机',
    beacon: '蓝牙信标',
    camera: '监控摄头',
    other: '其他设备'
  }
  return map[type] || '未知'
}

function getTypeTag(type) {
  const map = {
    checkpoint: 'primary',
    beacon: 'warning',
    camera: 'success',
    other: 'info'
  }
  return map[type]
}
</script>

<style scoped>
.form-tip {
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 4px;
}

.table-actions {
  display: flex;
  align-items: center;
  gap: 4px;
}
</style>
