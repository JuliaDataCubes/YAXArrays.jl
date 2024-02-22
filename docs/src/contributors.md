```@raw html
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
        avatar: 'https://pbs.twimg.com/profile_images/1727075196962574336/zB09YH0s_400x400.jpg',
        name: 'Lazaro Alonso',
        title: 'Scientist. Data Visualization',
        links: [
            { icon: 'github', link: 'https://github.com/lazarusA' },
            { icon: 'x', link: 'https://twitter.com/LazarusAlon' },
            { icon: 'linkedin', link: 'https://www.linkedin.com/in/lazaro-alonso/' },
            { icon: 'mastodon', link: 'https://julialang.social/@LazaroAlonso' }
            ]
        }
    ]

const partners =[
    {
        avatar: 'https://www.github.com/yyx990803.png',
        name: 'John',
        title: 'Creator' 
        },
    {
        avatar: 'https://www.github.com/yyx990803.png',
        name: 'Doe' 
        },
    ]
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
    (Add github list)
    </template>
    <template #members>
      <!-- <VPTeamMembers size="small" :members="partners" /> -->
    </template>
  </VPTeamPageSection>
</VPTeamPage>
```