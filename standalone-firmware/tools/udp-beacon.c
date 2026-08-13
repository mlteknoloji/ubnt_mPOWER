/* NetRelayMP UDP discovery for mips-linux (big-endian uClibc/musl).
 * Modes:
 *   udp-beacon listen [port] [statefile]
 *   udp-beacon send   [port] [message...]
 *   udp-beacon both   [port] [statefile] [interval] [message...]
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <time.h>
#include <stdint.h>

#define MAX_MSG 240
#define MAX_PEERS 64
#define LINE_MAX 320

struct peer {
  char ip[48];
  char mac[40];
  char id[64];
  char fw[40];
  char sno[64];
  char raw[MAX_MSG];
  time_t seen;
  int used;
};

static volatile int running = 1;
static void on_sig(int s) { (void)s; running = 0; }

static int make_sock(int port, int do_bind) {
  int s, one = 1;
  struct sockaddr_in a;
  s = socket(AF_INET, SOCK_DGRAM, 0);
  if (s < 0) return -1;
  setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
  setsockopt(s, SOL_SOCKET, SO_BROADCAST, &one, sizeof(one));
  if (do_bind) {
    memset(&a, 0, sizeof(a));
    a.sin_family = AF_INET;
    a.sin_addr.s_addr = htonl(INADDR_ANY);
    a.sin_port = htons((unsigned short)port);
    if (bind(s, (struct sockaddr *)&a, sizeof(a)) < 0) {
      close(s);
      return -1;
    }
  }
  return s;
}

static void trim(char *s) {
  char *p = s, *e;
  while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') p++;
  if (p != s) memmove(s, p, strlen(p) + 1);
  e = s + strlen(s);
  while (e > s && (e[-1] == ' ' || e[-1] == '\t' || e[-1] == '\r' || e[-1] == '\n')) {
    *--e = 0;
  }
}

/* Parse: "netRelay is here, mac, id, fw, sno" */
static int parse_msg(const char *msg, char *mac, char *id, char *fw, char *sno) {
  const char *p;
  char buf[MAX_MSG];
  char *a, *b, *c, *d;
  mac[0] = id[0] = fw[0] = sno[0] = 0;
  if (!msg) return 0;
  strncpy(buf, msg, sizeof(buf) - 1);
  buf[sizeof(buf) - 1] = 0;
  trim(buf);
  p = strstr(buf, "netRelay is here");
  if (!p) p = strstr(buf, "NetRelay is here");
  if (!p) p = strstr(buf, "netrelay is here");
  if (!p) return 0;
  p = strchr(p, ',');
  if (!p) return 0;
  p++;
  while (*p == ' ') p++;
  strncpy(buf, p, sizeof(buf) - 1);
  a = buf;
  b = strchr(a, ','); if (!b) return 0; *b++ = 0;
  c = strchr(b, ','); if (!c) return 0; *c++ = 0;
  d = strchr(c, ','); if (d) { *d++ = 0; } else { d = ""; }
  trim(a); trim(b); trim(c); trim(d);
  strncpy(mac, a, 39); mac[39] = 0;
  strncpy(id, b, 63); id[63] = 0;
  strncpy(fw, c, 39); fw[39] = 0;
  strncpy(sno, d, 63); sno[63] = 0;
  return 1;
}

static void json_esc(FILE *f, const char *s) {
  for (; s && *s; s++) {
    if (*s == '"' || *s == '\\') fputc('\\', f);
    if (*s == '\n' || *s == '\r') continue;
    fputc(*s, f);
  }
}

static void write_state(const char *path, struct peer *peers, int n, int port) {
  char tmp[256];
  FILE *f;
  int i, first = 1;
  time_t now = time(NULL);
  snprintf(tmp, sizeof(tmp), "%s.tmp", path);
  f = fopen(tmp, "w");
  if (!f) return;
  fprintf(f, "{\"ok\":true,\"port\":%d,\"updated\":%ld,\"peers\":[", port, (long)now);
  for (i = 0; i < n; i++) {
    if (!peers[i].used) continue;
    /* drop stale > 60s */
    if (now - peers[i].seen > 60) continue;
    if (!first) fputc(',', f);
    first = 0;
    fprintf(f, "{\"ip\":\""); json_esc(f, peers[i].ip);
    fprintf(f, "\",\"mac\":\""); json_esc(f, peers[i].mac);
    fprintf(f, "\",\"id\":\""); json_esc(f, peers[i].id);
    fprintf(f, "\",\"firmware\":\""); json_esc(f, peers[i].fw);
    fprintf(f, "\",\"hostname\":\""); json_esc(f, peers[i].sno);
    fprintf(f, "\",\"raw\":\""); json_esc(f, peers[i].raw);
    fprintf(f, "\",\"seen\":%ld,\"age\":%ld}", (long)peers[i].seen, (long)(now - peers[i].seen));
  }
  fprintf(f, "]}");
  fclose(f);
  rename(tmp, path);
}

static void upsert(struct peer *peers, int nmax, const char *ip, const char *msg) {
  char mac[40], id[64], fw[40], sno[64];
  int i, free_i = -1;
  time_t now = time(NULL);
  if (!parse_msg(msg, mac, id, fw, sno)) return;
  for (i = 0; i < nmax; i++) {
    if (!peers[i].used) { if (free_i < 0) free_i = i; continue; }
    if ((mac[0] && strcmp(peers[i].mac, mac) == 0) ||
        (strcmp(peers[i].ip, ip) == 0 && strcmp(peers[i].id, id) == 0)) {
      strncpy(peers[i].ip, ip, 47);
      strncpy(peers[i].mac, mac, 39);
      strncpy(peers[i].id, id, 63);
      strncpy(peers[i].fw, fw, 39);
      strncpy(peers[i].sno, sno, 63);
      strncpy(peers[i].raw, msg, MAX_MSG - 1);
      peers[i].seen = now;
      return;
    }
  }
  if (free_i < 0) free_i = 0;
  peers[free_i].used = 1;
  strncpy(peers[free_i].ip, ip, 47);
  strncpy(peers[free_i].mac, mac, 39);
  strncpy(peers[free_i].id, id, 63);
  strncpy(peers[free_i].fw, fw, 39);
  strncpy(peers[free_i].sno, sno, 63);
  strncpy(peers[free_i].raw, msg, MAX_MSG - 1);
  peers[free_i].ip[47] = peers[free_i].mac[39] = peers[free_i].id[63] = 0;
  peers[free_i].fw[39] = peers[free_i].sno[63] = peers[free_i].raw[MAX_MSG - 1] = 0;
  peers[free_i].seen = now;
}

static int do_send_to(int s, int port, const char *msg, uint32_t dest) {
  struct sockaddr_in a;
  memset(&a, 0, sizeof(a));
  a.sin_family = AF_INET;
  a.sin_port = htons((unsigned short)port);
  a.sin_addr.s_addr = dest;
  return sendto(s, msg, strlen(msg), 0, (struct sockaddr *)&a, sizeof(a));
}

static void do_send_all(int s, int port, const char *msg) {
  const char *ifaces[] = { "br0", "ath0", "ath1", "eth0", NULL };
  int i, fd;
  /* global broadcast */
  do_send_to(s, port, msg, htonl(INADDR_BROADCAST));
  /* directed broadcast per interface */
  fd = socket(AF_INET, SOCK_DGRAM, 0);
  if (fd < 0) return;
  for (i = 0; ifaces[i]; i++) {
    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, ifaces[i], IFNAMSIZ - 1);
    if (ioctl(fd, SIOCGIFBRDADDR, &ifr) == 0) {
      struct sockaddr_in *sin = (struct sockaddr_in *)&ifr.ifr_broadaddr;
      if (sin->sin_addr.s_addr != 0 && sin->sin_addr.s_addr != htonl(INADDR_BROADCAST))
        do_send_to(s, port, msg, sin->sin_addr.s_addr);
    }
  }
  close(fd);
}

static int run_both(int port, const char *state, int interval, const char *msg) {
  struct peer peers[MAX_PEERS];
  char buf[MAX_MSG + 4];
  struct sockaddr_in src;
  socklen_t sl;
  fd_set rfds;
  struct timeval tv;
  time_t last_send = 0, last_write = 0, now;
  int s, n;
  memset(peers, 0, sizeof(peers));
  signal(SIGTERM, on_sig);
  signal(SIGINT, on_sig);
  s = make_sock(port, 1);
  if (s < 0) {
    perror("socket/bind");
    return 1;
  }
  fcntl(s, F_SETFL, O_NONBLOCK);
  while (running) {
    now = time(NULL);
    if (msg && msg[0] && (now - last_send) >= interval) {
      do_send_all(s, port, msg);
      last_send = now;
    }
    FD_ZERO(&rfds);
    FD_SET(s, &rfds);
    tv.tv_sec = 1;
    tv.tv_usec = 0;
    if (select(s + 1, &rfds, NULL, NULL, &tv) > 0 && FD_ISSET(s, &rfds)) {
      sl = sizeof(src);
      n = recvfrom(s, buf, MAX_MSG, 0, (struct sockaddr *)&src, &sl);
      if (n > 0) {
        buf[n] = 0;
        upsert(peers, MAX_PEERS, inet_ntoa(src.sin_addr), buf);
      }
    }
    if ((now - last_write) >= 1) {
      write_state(state, peers, MAX_PEERS, port);
      last_write = now;
    }
  }
  close(s);
  return 0;
}

static int run_send_once(int port, const char *msg) {
  int s = make_sock(port, 0);
  if (s < 0) { perror("socket"); return 1; }
  do_send_all(s, port, msg);
  close(s);
  return 0;
}

int main(int argc, char **argv) {
  int port = 5555, interval = 5;
  const char *mode, *state = "/tmp/mpower-udp-peers.json";
  char msg[MAX_MSG];
  int i;
  if (argc < 2) {
    fprintf(stderr, "usage: %s both|listen|send [port] ...\n", argv[0]);
    return 2;
  }
  mode = argv[1];
  if (argc >= 3) port = atoi(argv[2]);
  if (port <= 0 || port > 65535) port = 5555;

  if (strcmp(mode, "send") == 0) {
    msg[0] = 0;
    for (i = 3; i < argc; i++) {
      if (msg[0]) strncat(msg, " ", sizeof(msg) - strlen(msg) - 1);
      strncat(msg, argv[i], sizeof(msg) - strlen(msg) - 1);
    }
    if (!msg[0]) snprintf(msg, sizeof(msg), "netRelay is here, unknown, unknown, unknown, unknown");
    return run_send_once(port, msg);
  }

  if (strcmp(mode, "listen") == 0 || strcmp(mode, "both") == 0) {
    if (argc >= 4) state = argv[3];
    if (strcmp(mode, "both") == 0) {
      if (argc >= 5) interval = atoi(argv[4]);
      if (interval < 1) interval = 5;
      msg[0] = 0;
      for (i = 5; i < argc; i++) {
        if (msg[0]) strncat(msg, " ", sizeof(msg) - strlen(msg) - 1);
        strncat(msg, argv[i], sizeof(msg) - strlen(msg) - 1);
      }
      return run_both(port, state, interval, msg[0] ? msg : NULL);
    }
    return run_both(port, state, 3600, NULL); /* listen-only: never send */
  }

  fprintf(stderr, "unknown mode %s\n", mode);
  return 2;
}
