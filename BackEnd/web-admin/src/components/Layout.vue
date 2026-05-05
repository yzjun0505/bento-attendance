<template>
  <div class="glass-app-wrapper" ref="appWrapper" @scroll="handleScroll">
    <!-- 悬浮顶部导航栏 -->
    <header class="floating-header" :class="{ 'header-hidden': isHeaderHidden }">
      <div class="header-content">
        <!-- 左侧区 -->
        <div class="header-left">
          <!-- Logo区 -->
          <div class="logo-wrap">
            <div class="logo-icon-box">
              <el-icon :size="22" color="#ffffff"><Odometer /></el-icon>
            </div>
            <span class="logo-text">打卡管理空间</span>
          </div>

          <!-- 高频导航 -->
          <nav class="high-freq-nav">
            <div 
              v-for="item in highFreqMenus" 
              :key="item.path"
              class="nav-item"
              :class="{ 'is-active': currentRoute === item.path }"
              @click="router.push(item.path)"
            >
              <el-icon><component :is="item.icon" /></el-icon>
              <span>{{ item.title }}</span>
            </div>
          </nav>
        </div>

        <!-- 中间留白 -->
        <div class="header-middle"></div>

        <!-- 右侧用户操作区 -->
        <div class="header-right">
          <!-- 低频管理折叠 -->
          <el-dropdown class="settings-dropdown" trigger="hover" @command="router.push($event)">
            <div class="settings-trigger">
              基础设置 <el-icon><ArrowDown /></el-icon>
            </div>
            <template #dropdown>
              <el-dropdown-menu class="dark-dropdown">
                <el-dropdown-item v-for="item in lowFreqMenus" :key="item.path" :command="item.path">
                  <el-icon><component :is="item.icon" /></el-icon>{{ item.title }}
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>

          <!-- 通知铃铛 -->
          <div class="bell-icon-wrap" title="消息通知" @click="router.push('/notifications')">
            <el-badge is-dot class="bell-badge">
              <el-icon :size="20"><Bell /></el-icon>
            </el-badge>
          </div>

          <!-- 昼夜切换按钮 -->
          <div class="theme-switch" @click="toggleTheme" title="切换昼夜模式">
            <el-icon :size="20">
              <component :is="isDark ? 'Moon' : 'Sunny'" />
            </el-icon>
          </div>

          <el-dropdown trigger="click" @command="handleUserCommand">
            <div class="user-info">
              <el-avatar :size="36" class="user-avatar">
                {{ userStore.userInfo?.name?.charAt(0) || 'A' }}
              </el-avatar>
              <div class="user-details" v-if="userStore.userInfo">
                <span class="user-name">{{ userStore.userInfo.name }}</span>
                <span class="user-role">{{ roleMap[userStore.userInfo.role] || '—' }}</span>
              </div>
              <el-icon class="user-arrow"><ArrowDown /></el-icon>
            </div>
            <template #dropdown>
              <el-dropdown-menu class="dark-dropdown">
                <el-dropdown-item command="profile">
                  <el-icon><User /></el-icon>个人信息
                </el-dropdown-item>
                <el-dropdown-item command="password">
                  <el-icon><Lock /></el-icon>修改密码
                </el-dropdown-item>
                <el-dropdown-item divided command="logout">
                  <el-icon><SwitchButton /></el-icon>退出系统
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </div>
    </header>

    <!-- 路由主内容区 (便当盒放置区) -->
    <main class="layout-main">
      <router-view v-slot="{ Component }">
        <transition name="fade" mode="out-in">
          <component :is="Component" />
        </transition>
      </router-view>
    </main>

    <!-- 个人信息对话框 -->
    <el-dialog v-model="profileDialogVisible" title="个人信息" width="480" :close-on-click-modal="false" class="dark-dialog">
      <el-form :model="profileForm" label-width="80px" label-position="right">
        <el-form-item label="姓名">
          <el-input v-model="profileForm.name" placeholder="请输入姓名" />
        </el-form-item>
        <el-form-item label="手机号">
          <el-input v-model="profileForm.phone" placeholder="请输入手机号" />
        </el-form-item>
        <el-form-item label="邮箱">
          <el-input v-model="profileForm.email" placeholder="请输入邮箱" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="profileDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="profileSaving" @click="handleSaveProfile">保存</el-button>
      </template>
    </el-dialog>

    <!-- 修改密码对话框 -->
    <el-dialog v-model="passwordDialogVisible" title="修改密码" width="480" :close-on-click-modal="false" class="dark-dialog">
      <el-form :model="passwordForm" label-width="80px" label-position="right">
        <el-form-item label="旧密码">
          <el-input v-model="passwordForm.oldPassword" type="password" show-password placeholder="请输入旧密码" />
        </el-form-item>
        <el-form-item label="新密码">
          <el-input v-model="passwordForm.newPassword" type="password" show-password placeholder="请输入新密码（至少6位）" />
        </el-form-item>
        <el-form-item label="确认密码">
          <el-input v-model="passwordForm.confirmPassword" type="password" show-password placeholder="请再次输入新密码" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="passwordDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="passwordSaving" @click="handleChangePassword">确认修改</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useUserStore } from '@/store/user'
import { ElMessageBox, ElMessage } from 'element-plus'
import { getCurrentUser, updateCurrentUser, changePassword } from '@/api/users'

const route = useRoute()
const router = useRouter()
const userStore = useUserStore()

const roleMap = { admin: '系统管理员', manager: '项目经理', worker: '工人' }
const isDark = ref(true)

// 导航栏隐藏/显示状态
const isHeaderHidden = ref(false)
const lastScrollY = ref(0)
const scrollThreshold = 50 // 滚动阈值，超过此值才触发

const highFreqMenus = [
  { path: '/dashboard', title: '工作台', icon: 'Grid' },
  { path: '/location', title: '实时位置', icon: 'MapLocation' },
  { path: '/checkin', title: '打卡记录', icon: 'LocationFilled' },
  { path: '/users', title: '人员管理', icon: 'UserFilled' },
  { path: '/projects', title: '项目管理', icon: 'OfficeBuilding' },
  { path: '/tracks', title: '轨迹回放', icon: 'MapLocation' }
]

const lowFreqMenus = [
  { path: '/schedules', title: '排班管理', icon: 'Calendar' },
  { path: '/holidays', title: '节假日管理', icon: 'CollectionTag' },
  { path: '/shifts', title: '班次管理', icon: 'AlarmClock' },
  { path: '/attendance-groups', title: '考勤组设置', icon: 'Clock' },
  { path: '/devices', title: '设备管理', icon: 'Cpu' },
  { path: '/watermarks', title: '水印设计', icon: 'Picture' },
  { path: '/offline-checkins', title: '离线打卡记录', icon: 'Connection' }
]

const currentRoute = computed(() => route.path)

// 滚动处理函数
function handleScroll(e) {
  const currentScrollY = e.target.scrollTop
  const diff = currentScrollY - lastScrollY.value
  
  // 向下滚动超过阈值 -> 隐藏导航栏
  if (diff > scrollThreshold && currentScrollY > 100) {
    isHeaderHidden.value = true
  }
  // 向上滚动 -> 显示导航栏
  else if (diff < -scrollThreshold) {
    isHeaderHidden.value = false
  }
  // 滚动到顶部 -> 显示导航栏
  else if (currentScrollY < 50) {
    isHeaderHidden.value = false
  }
  
  lastScrollY.value = currentScrollY
}

onMounted(async () => {
  const savedTheme = localStorage.getItem('theme-dark')
  if (savedTheme === 'false') {
    isDark.value = false
    document.documentElement.classList.remove('dark')
  } else {
    isDark.value = true
    document.documentElement.classList.add('dark')
  }

  try {
    await userStore.fetchProfile()
  } catch (e) {
    // Session 失效
  }
})

onUnmounted(() => {
  // 清理工作（如果需要）
})

function toggleTheme() {
  isDark.value = !isDark.value
  if (isDark.value) {
    document.documentElement.classList.add('dark')
    localStorage.setItem('theme-dark', 'true')
  } else {
    document.documentElement.classList.remove('dark')
    localStorage.setItem('theme-dark', 'false')
  }
}

const profileDialogVisible = ref(false)
const profileSaving = ref(false)
const profileForm = ref({ name: '', phone: '', email: '' })

const passwordDialogVisible = ref(false)
const passwordSaving = ref(false)
const passwordForm = ref({ oldPassword: '', newPassword: '', confirmPassword: '' })

async function openProfileDialog() {
  try {
    const res = await getCurrentUser()
    const data = res.data
    profileForm.value = {
      name: data.name || '',
      phone: data.phone || '',
      email: data.email || ''
    }
    profileDialogVisible.value = true
  } catch (e) {
    ElMessage.error('获取个人信息失败')
  }
}

async function handleSaveProfile() {
  profileSaving.value = true
  try {
    await updateCurrentUser(profileForm.value)
    ElMessage.success('个人信息更新成功')
    profileDialogVisible.value = false
    await userStore.fetchProfile()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '更新失败')
  } finally {
    profileSaving.value = false
  }
}

function openPasswordDialog() {
  passwordForm.value = { oldPassword: '', newPassword: '', confirmPassword: '' }
  passwordDialogVisible.value = true
}

async function handleChangePassword() {
  if (!passwordForm.value.oldPassword || !passwordForm.value.newPassword || !passwordForm.value.confirmPassword) {
    return ElMessage.warning('请填写所有密码字段')
  }
  if (passwordForm.value.newPassword.length < 6) {
    return ElMessage.warning('新密码长度不能少于6位')
  }
  if (passwordForm.value.newPassword !== passwordForm.value.confirmPassword) {
    return ElMessage.warning('两次输入的新密码不一致')
  }
  passwordSaving.value = true
  try {
    await changePassword({
      oldPassword: passwordForm.value.oldPassword,
      newPassword: passwordForm.value.newPassword
    })
    ElMessage.success('密码修改成功，请重新登录')
    passwordDialogVisible.value = false
    userStore.logout()
    router.push('/login')
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '密码修改失败')
  } finally {
    passwordSaving.value = false
  }
}

function handleUserCommand(command) {
  if (command === 'profile') {
    openProfileDialog()
  } else if (command === 'password') {
    openPasswordDialog()
  } else if (command === 'logout') {
    ElMessageBox.confirm('确定要退出打卡系统工作空间吗？', '退出确认', {
      confirmButtonText: '退出',
      cancelButtonText: '取消',
      type: 'warning',
      customClass: 'dark-message-box'
    }).then(() => {
      userStore.logout()
      router.push('/login')
    }).catch(() => {})
  }
}
</script>

<style scoped>
.glass-app-wrapper {
  height: 100vh;
  width: 100%;
  overflow-y: auto;
  overflow-x: hidden;
  position: relative;
}

/* 顶部悬浮导航 */
.floating-header {
  position: fixed;
  top: 24px;
  left: 50%;
  transform: translateX(-50%);
  width: calc(100% - 48px);
  max-width: 1440px;
  height: 60px;
  background: rgba(28, 30, 46, 0.85);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.05);
  border-radius: 16px;
  box-shadow: var(--shadow-md);
  z-index: 1000;
  display: flex;
  align-items: center;
  padding: 0 16px;
  transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.3s ease;
}

html:not(.dark) .floating-header {
  background: rgba(255, 255, 255, 0.85);
  border: 1px solid rgba(0, 0, 0, 0.05);
}

/* 导航栏隐藏状态 */
.floating-header.header-hidden {
  transform: translateX(-50%) translateY(-100px);
  opacity: 0;
  pointer-events: none;
}

.header-content {
  width: 100%;
  display: flex;
  align-items: center;
}

/* 左侧区 */
.header-left {
  display: flex;
  align-items: center;
  gap: 32px;
}

/* Logo 样式 */
.logo-wrap {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-shrink: 0;
  min-width: 0;
}

.logo-icon-box {
  width: 34px;
  height: 34px;
  background: var(--gradient-blue);
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
  flex-shrink: 0;
}

.logo-text {
  font-size: 16px;
  font-weight: 700;
  letter-spacing: -0.5px;
  color: var(--text-primary);
  white-space: nowrap;
}

/* 高频导航 */
.high-freq-nav {
  display: flex;
  align-items: center;
  gap: 8px;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border-radius: 20px;
  font-size: 14px;
  font-weight: 500;
  color: var(--text-secondary);
  cursor: pointer;
  transition: all 0.3s ease;
}

.nav-item:hover {
  color: var(--text-primary);
  background: rgba(255, 255, 255, 0.05);
}

html:not(.dark) .nav-item:hover {
  background: rgba(0, 0, 0, 0.03);
}

.nav-item.is-active {
  background: rgba(59, 130, 246, 0.1);
  color: var(--accent-blue);
  font-weight: 600;
}

/* 中间留白 */
.header-middle {
  flex: 1;
}

/* 用户区 */
.header-right {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
}

/* 基础设置触发器 */
.settings-trigger {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 14px;
  color: var(--text-secondary);
  cursor: pointer;
  padding: 6px 12px;
  border-radius: 6px;
  transition: color 0.3s;
}

.settings-trigger:hover {
  color: var(--text-primary);
}

/* 通知铃铛 */
.bell-icon-wrap {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-secondary);
  cursor: pointer;
  transition: all 0.3s;
}

.bell-icon-wrap:hover {
  background: rgba(255, 255, 255, 0.05);
  color: var(--text-primary);
}

html:not(.dark) .bell-icon-wrap:hover {
  background: rgba(0, 0, 0, 0.03);
}

.bell-badge {
  display: flex;
}

.theme-switch {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid var(--border-light);
  color: var(--text-primary);
  cursor: pointer;
  transition: var(--transition);
}

.theme-switch:hover {
  background: rgba(255, 255, 255, 0.1);
  transform: scale(1.05);
}

/* 适配亮色环境开关 */
html:not(.dark) .theme-switch {
  background: rgba(0, 0, 0, 0.03);
  color: var(--accent-orange);
}

html:not(.dark) .theme-switch:hover {
  background: rgba(0, 0, 0, 0.08);
}

.user-info {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 6px 12px 6px 6px;
  border-radius: 30px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--border-light);
  cursor: pointer;
  transition: var(--transition);
}

.user-info:hover {
  background: rgba(255, 255, 255, 0.08);
  border-color: rgba(255, 255, 255, 0.1);
}

.user-avatar {
  background: var(--gradient-green) !important;
  color: #fff;
  font-weight: 700;
}

.user-details {
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.user-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary);
  line-height: 1.2;
}

.user-role {
  font-size: 11px;
  color: var(--accent-blue);
  margin-top: 2px;
  font-weight: 500;
}

.user-arrow {
  color: var(--text-secondary);
  font-size: 12px;
  margin-left: 4px;
}

/* 主内容区 */
.layout-main {
  width: 100%;
}

/* 进出动画 */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s cubic-bezier(0.4, 0, 0.2, 1), transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.fade-enter-from {
  opacity: 0;
  transform: translateY(16px) scale(0.98);
}

.fade-leave-to {
  opacity: 0;
  transform: translateY(-16px) scale(0.98);
}
</style>
