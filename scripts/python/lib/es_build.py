'''
Created on Sep 12, 2017

@author: liza.dayoub@elastic.co
'''


import os
import requests
import re
import ast
import sys
import time
from urllib.parse import urlparse


class ElasticStackBuild:

    """Take build environment variables, parse and output individual product package URLs

    Any of the following can be specified, listed in order of precedence:

    1. Individual URLs:
        ES_BUILD_<PRODUCT>_URL
            where <PRODUCT> is one of
                ELASTICSEARCH, KIBANA, LOGSTASH, FILEBEAT, HEARTBEAT, METRICBEAT, PACKETBEAT,
                WINLOGBEAT, BEATS_DASHBOARDS, XPACK, XPACK_ELASTICSEARCH, XPACK_KIBANA, XPACK_LOGSTASH
        example:
            ES_BUILD_ELASTICSEARCH_URL=https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-5.6.0.zip

    2. Build URL
        ES_BUILD_URL and ES_BUILD_PKG_EXT
        optional ES_BUILD_ARCH to test 32 bit images or darwin platform, the default is 64 bit windows or linux.
        example:
            ES_BUILD_URL=https://staging.elastic.co/5.5.3-a605b2d5/summary.html
            ES_BUILD_PKG_EXT=tar

    3. Build Server and Id
        ES_BUILD_SERVER, ES_BUILD_ID and ES_BUILD_PKG_EXT
        optional ES_BUILD_ARCH to test 32 bit images or darwin platform:
        example:
            ES_BUILD_SERVER=staging.elastic.co
            ES_BUILD_ID=5.5.3-a605b2d5
            ES_BUILD_PKG_EXT=tar
            ES_BUILD_ARCH = "darwin 64 bit"

    Note: To add upgrade from build information, use UPGRADE_ as a prefix to env variable and follow above settings
        example:
            UPGRADE_ES_BUILD_URL=https://elastic.co/5.6.0
            UPGRADE_ES_BUILD_PKG_EXT=rpm
            ES_BUILD_URL=https://staging.elastic.co/6.0.0-a605b2d5/summary.html
            ES_BUILD_PKG_EXT=rpm

    """

    _public_servers = ['https://elastic.co', 'https://artifacts.elastic.co']
    _snapshot_servers = ['https://snapshots.elastic.co']
    _valid_windows_extensions = ['zip', 'msi']
    _valid_extensions = ['tar', 'tar.gz', 'rpm', 'deb', 'zip', 'msi']

    def __init__(self, upgrade=False):

        self.upgrade = upgrade

        env_vars = {'_env_elasticsearch_url': 'ES_BUILD_ELASTICSEARCH_URL',
                    '_env_kibana_url': 'ES_BUILD_KIBANA_URL',
                    '_env_logstash_url': 'ES_BUILD_LOGSTASH_URL',
                    '_env_filebeat_url': 'ES_BUILD_FILEBEAT_URL',
                    '_env_heartbeat_url': 'ES_BUILD_HEARTBEAT_URL',
                    '_env_metricbeat_url': 'ES_BUILD_METRICBEAT_URL',
                    '_env_packetbeat_url': 'ES_BUILD_PACKETBEAT_URL',
                    '_env_auditbeat_url': 'ES_BUILD_AUDITBEAT_URL',
                    '_env_winlogbeat_url': 'ES_BUILD_WINLOGBEAT_URL',
                    '_env_beats_dashboards_url': 'ES_BUILD_BEATS_DASHBOARDS_URL',
                    '_env_apm_server_url': 'ES_BUILD_APM_SERVER_URL',
                    '_env_xpack_url': 'ES_BUILD_XPACK_URL',
                    '_env_xpack_elasticsearch_url': 'ES_BUILD_XPACK_ELASTICSEARCH_URL',
                    '_env_xpack_kibana_url': 'ES_BUILD_XPACK_KIBANA_URL',
                    '_env_xpack_logstash_url': 'ES_BUILD_XPACK_LOGSTASH_URL',
                    '_env_build_url': 'ES_BUILD_URL',
                    '_env_server': 'ES_BUILD_SERVER',
                    '_env_build_id': 'ES_BUILD_ID',
                    '_env_extension': 'ES_BUILD_PKG_EXT',
                    '_env_architecture': 'ES_BUILD_ARCH',
                    '_env_oss': 'ES_BUILD_OSS'
                    }

        for attr in env_vars.keys():
            if upgrade:
                value = os.getenv('UPGRADE_' + env_vars[attr], '')
            else:
                value = os.getenv(env_vars[attr], '')
                if attr == '_env_oss':
                    value = ast.literal_eval(value.title())
            setattr(self, attr, value)

        # If msi is specified, default env_extension to zip, since only elasticsearch has an msi
        self._msi_ext = False
        if self.extension == 'msi':
            self._env_extension = 'zip'
            self._msi_ext = True

        # If build url is specified, split into server and build id
        if self._env_build_url:
            regex = re.compile('^http://|https://.*')
            if regex.search(self._env_build_url):
                parser = urlparse(self._env_build_url)
            else:
                parser = urlparse('https://' + self._env_build_url)
            self._env_server = parser.hostname
            if parser.path:
                self._env_build_id = parser.path.split('/')[1]

    @property
    def elasticsearch_package_url(self):
        if self._msi_ext:
            return self._get_url(self._env_elasticsearch_url, 'elasticsearch', parent_name='windows-installers/elasticsearch', ext='msi')
        return self._get_url(self._env_elasticsearch_url, 'elasticsearch')

    @property
    def kibana_package_url(self):
        return self._get_url_arch(self._env_kibana_url, 'kibana')

    @property
    def logstash_package_url(self):
        return self._get_url(self._env_logstash_url, 'logstash')

    @property
    def filebeat_package_url(self):
        return self._get_url_arch(self._env_filebeat_url, 'filebeat', parent_name='beats/filebeat')

    @property
    def heartbeat_package_url(self):
        return self._get_url_arch(self._env_heartbeat_url, 'heartbeat', parent_name='beats/heartbeat')

    @property
    def metricbeat_package_url(self):
        return self._get_url_arch(self._env_metricbeat_url, 'metricbeat', parent_name='beats/metricbeat')

    @property
    def packetbeat_package_url(self):
        return self._get_url_arch(self._env_packetbeat_url, 'packetbeat', parent_name='beats/packetbeat')

    @property
    def auditbeat_package_url(self):
        return self._get_url_arch(self._env_auditbeat_url, 'auditbeat', parent_name='beats/auditbeat')

    @property
    def winlogbeat_package_url(self):
        return self._get_url_arch(self._env_winlogbeat_url, 'winlogbeat', parent_name='beats/winlogbeat')

    @property
    def beats_dashboards_package_url(self):
        return self._get_url(self._env_beats_dashboards_url, 'beats-dashboards', parent_name='beats/beats-dashboards', ext='zip')

    @property
    def apm_server_package_url(self):
        return self._get_url_arch(self._env_apm_server_url, 'apm-server', parent_name='apm-server')

    @property
    def xpack_package_url(self):
        return self._get_url(self._env_xpack_url, 'x-pack', parent_name='packs/x-pack', ext='zip')

    @property
    def xpack_elasticsearch_package_url(self):
        return self._get_url(self._env_xpack_elasticsearch_url, 'x-pack', parent_name='elasticsearch-plugins/x-pack', ext='zip')

    @property
    def xpack_kibana_package_url(self):
        return self._get_url(self._env_xpack_kibana_url, 'x-pack', parent_name='kibana-plugins/x-pack', ext='zip')

    @property
    def xpack_logstash_package_url(self):
        return self._get_url(self._env_xpack_logstash_url, 'x-pack', parent_name='logstash-plugins/x-pack', ext='zip')

    @property
    def server(self):
        regex = re.compile('^http://|https://.*')
        if not self._env_server or regex.search(self._env_server):
            server = self._env_server.rstrip('/').strip()
        else:
            server = 'https://' + self._env_server.rstrip('/').strip()
        server = re.sub('^https://elastic.co$', 'https://artifacts.elastic.co', server)
        return server

    @property
    def version(self):
        if not self._env_build_id:
            return self._env_build_id.strip()
        splitstr = self._env_build_id.split('-')
        if len(splitstr) > 1:
            del splitstr[-1]
        newstr = '-'.join(splitstr)
        if self.server in self._snapshot_servers:
            newstr += '-SNAPSHOT'
        return newstr.strip()

    @property
    def extension(self):
        if not self._env_extension:
            return self._env_extension.strip()
        pkgext = self._env_extension.lstrip('.').strip()
        pkgext = re.sub("^tar$", "tar.gz", pkgext)
        if pkgext in self._valid_extensions:
            return pkgext
        return ''

    @property
    def architecture(self):
        translate_arch = {'linux deb 32': 'i386',
                          'linux deb 64': 'amd64',
                          'linux rpm 32': 'i686',
                          'linux rpm 64': 'x86_64',
                          'linux tar.gz 32': 'linux-x86',
                          'linux tar.gz 64': 'linux-x86_64',
                          'darwin tar.gz 64': 'darwin-x86_64',
                          'windows zip 32': 'windows-x86',
                          'windows zip 64': 'windows-x86_64'}

        ext = self.extension
        r = re.search(r'^(windows|darwin|linux)*[\s|\-|\_]*(64|32){1}[\s|\-|\_]*[bit]*$', self._env_architecture.lower())
        if not hasattr(r, 'group') and ext in self._valid_windows_extensions:
            return translate_arch.get('windows zip 64', '')
        if not hasattr(r, 'group') and ext not in self._valid_windows_extensions:
            return translate_arch.get('linux ' + ext + ' 64', '')
        platform = r.group(1)
        arch = r.group(2)
        if platform and arch:
            return translate_arch.get(platform + ' ' + ext + ' ' + arch, '')
        if not arch:
            arch = '64'
        if not platform and ext in self._valid_windows_extensions:
            platform = 'windows'
        if not platform and ext not in self._valid_windows_extensions:
            platform = 'linux'
        return translate_arch.get(platform + ' ' + ext + ' ' + arch, '')

    def ping(self, url):
        invalid_url = False
        try:
            r = requests.head(url)
            if r.status_code == 200:
                return True
            if 'x-pack' not in url:
                print('Status code: ' + str(r.status_code))
                # Retry the invalid URL
                for i in range(5):
                    r = requests.head(url)
                    print('RETRYING...Status code: ' + str(r.status_code))
                    if r.status_code == 200:
                        return True
                    time.sleep(1)
                invalid_url = True
        except:
            raise Exception('Error! Unreachable URL: ' + url)
        if invalid_url:
            raise Exception('Error! Invalid URL: ' + url)
        return False

    def _get_url(self, specific_url, name, parent_name='', ext=''):
        if specific_url:
            if self.ping(specific_url):
                return specific_url
        else:
            if not parent_name:
                parent_name = name
            if not ext:
                ext = self.extension
            server = self.server
            version = self.version
            if server and version and ext:
                if server in self._public_servers:
                    url = server + '/downloads/' + parent_name + '/' + name + '-' + version + '.' + ext
                elif self._env_oss and 'beats-dashboards' not in parent_name:
                    name += '-oss'
                    url = server + '/' + self._env_build_id + '/downloads/' + parent_name + '/' + name + '-' + version + '.' + ext
                else:
                    url = server + '/' + self._env_build_id + '/downloads/' + parent_name + '/' + name + '-' + version + '.' + ext

                if self.ping(url):
                    return url
        return ''

    def _get_url_arch(self, specific_url, name, parent_name='', ext=''):
        if specific_url:
            if self.ping(specific_url):
                return specific_url
        else:
            if not parent_name:
                parent_name = name
            if not ext:
                ext = self.extension
            server = self.server
            version = self.version
            if name == "winlogbeat" and ext not in self._valid_windows_extensions:
                return ''
            if server and version and ext:
                arch = self.architecture
                if name == 'kibana':
                    arch = re.sub('windows-x86_64', 'windows-x86', arch)
                if server in self._public_servers:
                    url = server + '/downloads/' + parent_name + '/' + name + '-' + version + '-' +  arch + '.' + ext
                elif self._env_oss:
                    name += '-oss'
                    if 'beats' in parent_name:
                        url = server + '/' + self._env_build_id + '/downloads/' + parent_name + '/' + name + '-' + version + '-' + arch + '.' + ext
                    else:
                        url = server + '/' + self._env_build_id + '/downloads/' + parent_name + '/' + name + '-' + version + '-' + arch + '.' + ext
                else:
                    url = server + '/' + self._env_build_id + '/downloads/' + parent_name + '/' + name + '-' + version + '-' +  arch + '.' + ext
                if self.ping(url):
                    return url
        return ''
