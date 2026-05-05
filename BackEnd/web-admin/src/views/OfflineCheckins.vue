<template>
  <div class="page-container fade-in-up">
    <div class="unified-card">
      <div class="header-section">
        <div>
          <h2 class="page-title">离线打卡记录</h2>
          <p class="page-subtitle">查看和同步离线打卡数据</p>
        </div>
        <el-button type="primary" :icon="Refresh" :loading="syncing" @click="handleSync">一键同步</el-button>
      </div>

      <div class="filter-section">
        <el-select v-model="filters.sync_status" placeholder="同步状态" clearable style="width: 130px" @change="loadData">
          <el-option label="未同步" value="pending" />
          <el-option label="已同步" value="synced" />
        </el-select>
        <el-input
          v-model="filters.keyword"
          placeholder="搜索用户"
          :prefix-icon="Search"
          clearable
          style="width: 180px"
          @clear="loadData"
          @keyup.enter="loadData"
        />
        <el-button type="primary" :icon="Search" @click="loadData">搜索</el-button>
      </div>

      <div class="table-section">
        <el-table :data="tableData" v-loading="loading" class="custom-table" style="width: 100%">
        <el-table-column prop="user_name" label="用户" width="100" />
        <el-table-column prop="type" label="打卡类型" width="100">
          <template #default="{ row }">
            <el-tag :type="row.type === 'clock_in' ? 'success' : 'warning'" size="small" effect="dark" round>
              {{ row.type === 'clock_in' ? '上班' : row.type === 'clock_out' ? '下班' : row.type }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="address" label="位置" min-width="200" show-overflow-tooltip />
        <el-table-column prop="local_timestamp" label="本地打卡时间" width="180">
          <template #default="{ row }">{{ formatTime(row.local_timestamp) }}</template>
        </el-table-column>
        <el-table-column prop="sync_status" label="同步状态" width="100">
          <template #default="{ row }">
            <el-tag v-if="row.sync_status === 'synced'" type="success" size="small" effect="dark" round>已同步</el-tag>
            <el-tag v-else type="warning" size="small" effect="dark" round>未同步</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="synced_at" label="同步时间" width="180">
          <template #default="{ row }">{{ row.synced_at ? formatTime(row.synced_at) : '—' }}</template>
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
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { getOfflineCheckins, syncOfflineCheckins } from '@/api/offlineCheckins'
import { ElMessage } from 'element-plus'
import { Search, Refresh } from '@element-plus/icons-vue'

const loading = ref(false)
const syncing = ref(false)
const tableData = ref([])
const filters = reactive({ keyword: '', sync_status: '' })
const pagination = reactive({ page: 1, pageSize: 20, total: 0 })

onMounted(() => loadData())

async function loadData() {
  loading.value = true
  try {
    const res = await getOfflineCheckins({ ...filters, ...pagination })
    tableData.value = res.data.list || res.data || []
    if (res.data.total !== undefined) pagination.total = res.data.total
  } catch (e) {
    console.error('加载离线打卡记录失败:', e)
  } finally {
    loading.value = false
  }
}

async function handleSync() {
  syncing.value = true
  try {
    const res = await syncOfflineCheckins()
    const count = res.data?.synced_count ?? res.data?.synced ?? '?'
    ElMessage.success(`同步完成，已同步 ${count} 条记录`)
    loadData()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '同步失败')
  } finally {
    syncing.value = false
  }
}

function formatTime(val) {
  if (!val) return '—'
  // 后端返回本地时间字符串，替换空格为T确保浏览器按本地时间解析
  const d = new Date(typeof val === 'string' ? val.replace(' ', 'T') : val)
  if (isNaN(d.getTime())) return val
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
}
</script>
