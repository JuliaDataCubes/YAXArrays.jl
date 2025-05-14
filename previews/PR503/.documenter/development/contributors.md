---
layout: page
---
<script setup>
import {
  VPTeamPage,
  VPTeamPageTitle,
  VPTeamMembers,
  VPTeamPageSection
} from 'vitepress/theme'

const coreMembers = [
    {
        avatar: 'https://www.bgc-jena.mpg.de/employee_images/121366-1667825290?t=eyJ3aWR0aCI6MjEzLCJoZWlnaHQiOjI3NCwiZml0IjoiY3JvcCIsImZpbGVfZXh0ZW5zaW9uIjoid2VicCIsInF1YWxpdHkiOjg2fQ%3D%3D--3e1d41ff4b1ea8928e6734bc473242a90f797dea',
        name: 'Fabian Gans',
        title: 'Geoscientific Programmer',
        links: [
            { icon: 'github', link: 'https://github.com/meggart' },
            ]
        },
    {
        avatar: 'https://avatars.githubusercontent.com/u/17124431?v=4',
        name: 'Felix Cremer',
        title: 'PhD Candidate in Remote Sensing',
        links: [
            { icon: 'github', link: 'https://github.com/felixcremer' },
            ]
        },
    {
        avatar: 'https://avatars.githubusercontent.com/u/2534009?v=4',
        name: 'Rafael Schouten',
        title: 'Spatial/ecological modelling',
        links: [
            { icon: 'github', link: 'https://github.com/rafaqz' },
            ]
        },
    {
        avatar: 'https://avatars.githubusercontent.com/u/19525261?v=4',
        name: 'Lazaro Alonso',
        title: 'Scientist. Data Visualization',
        links: [
            { icon: 'github', link: 'https://github.com/lazarusA' },
            { icon: 'bluesky', link: 'https://bsky.app/profile/lazarusa.bsky.social' },
            { icon: 'x', link: 'https://twitter.com/LazarusAlon' },
            { icon: 'linkedin', link: 'https://www.linkedin.com/in/lazaro-alonso/' },
            { icon: 'mastodon', link: 'https://julialang.social/@LazaroAlonso' }
            ]
        }
    ]

// const partners =[
//     {
//         avatar: 'https://www.github.com/yyx990803.png',
//         },
//     {
//         avatar: 'https://www.github.com/yyx990803.png',
//         },
//     ]
</script>

<VPTeamPage>
  <VPTeamPageTitle>
    <template #title>Contributors</template>
    <template #lead>
    <strong>Current core contributors </strong> <br>
    <div align="justify">
    They have taking the lead for the ongoing organizational maintenance and technical direction of <font color="orange">YAXArrays.jl</font>, <font color="orange">DiskArrays.jl</font> and <font color="orange">DimensionalData.jl</font>.
    </div>
    </template>
  </VPTeamPageTitle>
  <VPTeamMembers size="small" :members="coreMembers" />
  <VPTeamPageSection>
    <template #title>Our valuable contributors</template>
    <template #lead>
    We appreciate all contributions from the Julia community so that this ecosystem can thrive.<br>
    </template>
    <template #members>
      <!-- <VPTeamMembers size="small" :members="partners" /> -->
      <div class="row">
        <a href="https://github.com/meggart" target="_blank"><img src="https://avatars.githubusercontent.com/u/2539563?v=4"></a>
        <a href="https://github.com/felixcremer" target="_blank"><img src="https://avatars.githubusercontent.com/u/17124431?v=4"></a>
        <a href="https://github.com/lazarusA" target="_blank"><img src="https://avatars.githubusercontent.com/u/19525261?v=4"></a>
        <a href="https://github.com/gdkrmr" target="_blank"><img src="https://avatars.githubusercontent.com/u/12512930?v=4"></a>
        <a href="https://github.com/apps/github-actions" target="_blank"><img src="https://avatars.githubusercontent.com/in/15368?v=4"></a>
        <a href="https://github.com/pdimens" target="_blank"><img src="https://avatars.githubusercontent.com/u/19176506?v=4"></a>
        <a href="https://github.com/twinGu" target="_blank"><img src="https://avatars.githubusercontent.com/u/29449917?v=4"></a>
        <a href="https://github.com/dpabon" target="_blank"><img src="https://avatars.githubusercontent.com/u/13040959?v=4"></a>
        <a href="https://github.com/Qfl3x" target="_blank"><img src="https://avatars.githubusercontent.com/u/20775896?v=4"></a>
        <a href="https://github.com/kongdd" target="_blank"><img src="https://avatars.githubusercontent.com/u/9815742?v=4"></a>
        <a href="https://github.com/MartinuzziFrancesco" target="_blank"><img src="https://avatars.githubusercontent.com/u/10376688?v=4"></a>
        <a href="https://github.com/Sonicious" target="_blank"><img src="https://avatars.githubusercontent.com/u/16307399?v=4"></a>
        <a href="https://github.com/rafaqz" target="_blank"><img src="https://avatars.githubusercontent.com/u/2534009?v=4"></a>
        <a href="https://github.com/danlooo" target="_blank"><img src="https://avatars.githubusercontent.com/u/5780565?v=4"></a>
        <a href="https://github.com/MarkusZehner" target="_blank"><img src="https://avatars.githubusercontent.com/u/56972144?v=4"></a>
        <a href="https://github.com/Balinus" target="_blank"><img src="https://avatars.githubusercontent.com/u/3630311?v=4"></a>
        <a href="https://github.com/singularitti" target="_blank"><img src="https://avatars.githubusercontent.com/u/25192197?v=4"></a>
        <a href="https://github.com/ckrich" target="_blank"><img src="https://avatars.githubusercontent.com/u/28727495?v=4"></a>
        <a href="https://github.com/apps/femtocleaner" target="_blank"><img src="https://avatars.githubusercontent.com/in/4123?v=4"></a>
        <a href="https://github.com/ikselven" target="_blank"><img src="https://avatars.githubusercontent.com/u/10441332?v=4"></a>
        <a href="https://github.com/linamaes" target="_blank"><img src="https://avatars.githubusercontent.com/u/7131773?v=4"></a>
      </div>
    </template>
  </VPTeamPageSection>
</VPTeamPage>

<style>
.row img {
  border-radius: 50%;
  width: 60px;
  height: 60px;
}
.row {
  display: flex;
  flex-wrap: wrap;
  padding: 0 4px;
}
</style>

