import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/Login.vue'),
    meta: { title: '登录', public: true }
  },
  {
    path: '/',
    component: () => import('@/components/Layout.vue'),
    redirect: '/dashboard',
    children: [
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: () => import('@/views/Dashboard.vue'),
        meta: { title: '工作台', icon: 'Odometer' }
      },
      {
        path: 'users',
        name: 'Users',
        component: () => import('@/views/Users.vue'),
        meta: { title: '人员管理', icon: 'User' }
      },
      {
        path: 'checkin',
        name: 'Checkin',
        component: () => import('@/views/Checkin.vue'),
        meta: { title: '打卡记录', icon: 'Clock' }
      },
      {
        path: 'location',
        name: 'Location',
        component: () => import('@/views/Location.vue'),
        meta: { title: '实时位置', icon: 'Location' }
      },
      {
        path: 'projects',
        name: 'Projects',
        component: () => import('@/views/Projects.vue'),
        meta: { title: '项目管理', icon: 'OfficeBuilding' }
      },
      {
        path: 'devices',
        name: 'Devices',
        component: () => import('@/views/Devices.vue'),
        meta: { title: '设备管理', icon: 'Cpu' }
      },
      {
        path: 'watermarks',
        name: 'Watermarks',
        component: () => import('@/views/Watermarks.vue'),
        meta: { title: '水印设计', icon: 'Picture' }
      },
      {
        path: 'notifications',
        name: 'Notifications',
        component: () => import('@/views/Notifications.vue'),
        meta: { title: '消息通知', icon: 'Bell' }
      },
      {
        path: 'attendance-groups',
        name: 'AttendanceGroups',
        component: () => import('@/views/AttendanceGroups.vue'),
        meta: { title: '考勤组设置', icon: 'Clock' }
      },
      {
        path: 'anti-fake-query',
        name: 'AntiFakeQuery',
        component: () => import('@/views/AntiFakeQuery.vue'),
        meta: { title: '防伪码查询', icon: 'Search' }
      },
      {
        path: 'shifts',
        name: 'Shifts',
        component: () => import('@/views/Shifts.vue'),
        meta: { title: '班次管理', icon: 'AlarmClock' }
      },
      {
        path: 'schedules',
        name: 'Schedules',
        component: () => import('@/views/Schedules.vue'),
        meta: { title: '排班管理', icon: 'Calendar' }
      },
      {
        path: 'holidays',
        name: 'Holidays',
        component: () => import('@/views/Holidays.vue'),
        meta: { title: '节假日管理', icon: 'CollectionTag' }
      },
      {
        path: 'offline-checkins',
        name: 'OfflineCheckins',
        component: () => import('@/views/OfflineCheckins.vue'),
        meta: { title: '离线打卡记录', icon: 'Connection' }
      },
      {
        path: 'tracks',
        name: 'Tracks',
        component: () => import('@/views/Tracks.vue'),
        meta: { title: '轨迹回放', icon: 'MapLocation' }
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach((to, from, next) => {
  document.title = `${to.meta.title || '管理系统'} - 打卡管理系统`
  const token = localStorage.getItem('token')
  if (!to.meta.public && !token) {
    next('/login')
  } else {
    next()
  }
})

export default router
